# 2009-1-13

# CommentClass pacakage임을 알린다.
package CommentClass;

use warnings;
use strict;
use Carp;
use DateTime; # 댓글이 쓰여진 시간이 Unix 시간으로 TTXML에 기록되기에 이를 사용한다.
use utf8; # 이글루스 정보들은 encoding으로 utf8으로 되어있기에 사용.

my $description; # 본문 - TTXML : content
# password 역시 이글루스에서 공개하지 않기에 null로 처리합니다. - TTXML : password
my $time; # 시간 - TTXML : written - 타임 표현으로 저장
#my $id; # 덧글 id - 전에 무슨 이유로 만들었는지 모르겠으나 TTXML에 없기에 제외, 아마도 그 때는 이글루스 백업 및 통계를 내기 위해 만들었기에 이글루스 로그인자라면 그의 아이디를 기억하기 위해서 만든 듯싶다.
my $is_secret; #비공개 덧글 확인. 0이면 공개 덧글, 1이면 비공개 덧글. - TTXML : secret
my $href; # 덧글을 적은 사람 블로그 주소. 안 적는 경우도 있으므로 default는 null - TTXML : commenter - homepage
my $who; # 덧글 적은 사람 이름 - TTXML : commenter - name
# IP는 이글루스에서 제대로 제공하지 않고, 굳이 있을 필요가 없을 듯싶어 XML을 만들 때 null로 처리합니다. - TTXML : commenter - ip
# 확인해보니 IP를 넣지 않았더니 복원을 한 IP가 Textcube에 복원할 때 자동으로 기록됩니다.
my $is_root; # root인 경우 답댓글을 가질 수 있음. root라면 1, 답댓글 : 0
#my @child_comments; # root인 경우 답댓글의 배열을 가지고 있는다. 답댓글이면 null
# 답댓글을 처리하는 것이 골치였습니다. 하지만 댓글 목록을 받아 처리하기로 하여 굳이 할 필요가 없어졌음.
my $postid; # 댓글이 적혀있는 글 id.
my $commentid; # 댓글 id

# 생성자
# 뒤의 두 개는 레퍼런스로 받는다.
sub new ($$$$\%\@)
{
	my $class = shift;
	# 이글루스 정보, 백업하는 블로그 주소, 댓글 목록에서 해당 댓글 정보가 담겨있는 html 코드, 프로그램이 시작한 시각(24시간 내의 댓글을 새로 받기 위해.), all_post를 찾기 위한 hash table, PostClass 배열.
	my ($egloosinfo, $blogurl, $comment_field, $dt_today, $postid_index, $all_post) = @_;
	
	
#	답글여부.
	# 정규표현식 안에 구문을 적으면 escape 문자를 신경써야하기에 골치가 아프다.
	# 따라서 이런 식으로 문자열 변수를 만들어 처리한다.
	# 다른 코드에서도 이런식으로 한 곳이 많다.
	# 성능은 떨어지겠지만 코드 개발 및 읽기에 효율적이라 생각한다.
	# 다만, ()의 경우 앞에 \을 붙여야 괄호로 인식한다.
	my $needle1 = '<span style="font-size:11px;color:#929292;">\(답글\)</span>';
	if($comment_field =~ m/$needle1/i)
	{
		$is_root = 0; # 있으니까 답댓글.
	}
	else
	{
		$is_root = 1; # 없으니까 root 댓글. 여기서 root 댓글이란 답댓글이 아닌 것. 딱히 이름을 무어라 불러야 할지 몰라서 Tree의 root를 붙였다.
	}
	
#	비밀글 여부.
	$needle1 = '<img src="http://md.egloos.com/img/eg/post_security.gif" width="13" height="16" align="texttop" alt="비공개" />';
	if($comment_field =~ m/$needle1/i)
	{
		$is_secret = 1; # 있으니까 비밀 댓글..
	}
	else
	{
		$is_secret = 0; # 없으니까 공개 댓글..
	}
	
#	postid와 댓글 id 가져오기.
	$needle1 = '<input type="checkbox"name="chk" value="';
	$comment_field =~ m/$needle1(\d+?)-(.+?)"/i;
	$postid = $1;
	$commentid = $2;
	
#	댓글 적은이 정보 가져오기.
#	예제.
#	<td width="100" align="center" class="black"><a href="http://NoSyu.egloos.com"  target="_new">NoSyu</a></td>
#	<td width="100" align="center" class="black">뎅궁씨</td>
	$comment_field =~ m/<td width="100" align="center" class="black">(.*?)<\/td>/i;
	my $temp = $1;
#	댓글이의 주소가 없는 경우가 있음.
	if($temp =~ m/<a href="(.*?)"  target="_new">(.*?)<\/a>/i)
	{
		$href = $1;
		$who = $2;
#		자기 자신이 쓴 글이면 블로그 주소를 바꾼다.
		if($blogurl eq $href)
		{
			# 물론 사용자가 새로운 블로그 주소를 입력한 경우에만 한다.
			if(!('' eq $egloosinfo->{newblogurl}))
			{
				$href = $egloosinfo->{newblogurl};
			}
		}
	}
	else
	{
		# 댓글 주소가 없는 경우.
		$href = '';
		$who = $temp;
	}
	
	
#	덧글이 적혀진 글의 페이지 가져오기. - 수정 2009.01.01
#	댓글 하나마다 페이지에 접근하는 것이 아니라 PostClass를 만들 때 해당 페이지를 하드에 저장한다.
#	따라서 댓글마다 접근하는 것에서 글마다 접근하는 것으로 바뀌어 속도도 향상되고 댓글을 처리할 때 이글루스에서 접근을 끊을 일이 거의 없어졌다.
#	my $content = BackUpEgloos_Subs::getpage($blogurl . '/' . $postid);
#	댓글이 프로그램이 시작하는 오늘 적혔다면 다시 읽어오기. - 2009-1-13
#	이는 Mizar님의 테스트로 알게 되었는데, 프로그램을 돌리기 시작하고나서 댓글이 달리는 경우 댓글 목록에는 나오지만 글은 이미 모두 다운을 받아 PoatClass의 html 코드 안에 해당 댓글이 없는 경우가 생긴다.
#	이럴 때 어김없이 에러를 토해내기에 골치가 아팠다.
#	따라서 24시간 안에 작성된 댓글의 경우 해당 글 페이지에 다시 접근하여 html 코드를 가져온다.
#	여기서 PostClass를 고칠 수 없기에(정확하게는 하라면 할 수 있지만, 변수 하나를 만들어 24시간 안에 댓글이 올라와 새롭게 받은 것이라는 변수를 할당해야 하기에 골치가 아프다.) 댓글마다 접근하는 수밖에 없다.
#	이글루스에서 접속을 끊을 수 있기에 버그가 발생할 수 있는 코드이다.
#	되도록 사용자에게 사람들이 댓글을 적지 않는 시간에 하기를 요청한다.
#	예제.
#	<td width="80" align="center" class="black">2009/01/06</td></tr>
	my $content; # 해당 페이지
	$comment_field =~ m/<td width="80" align="center" class="black">(\d{4})\/(\d{2})\/(\d{2})<\/td><\/tr>/i;
	my $temp_time = DateTime->new(year => $1, month  => $2, day => $3,
						hour => 0, minute => 0, second => 0, time_zone => 'Asia/Seoul');
	
#	24시간 안에 올라온 것이 아니기에 미리 저장한 곳에서 가져온다.
#	이글루스가 임시 조치한 글의 경우 목록에 글이 없다.
#	따라서 여기서 만들어 처리한다. - 2009-1-13, http://nosyu.pe.kr/1796
#	도움 페이지.
#	http://www.cs.mcgill.ca/~abatko/computers/programming/perl/howto/hash/
	if(exists $postid_index->{$postid})
	{
		$content = $all_post->[$postid_index->{$postid}]->{content_html};
	}
	else
	{
#		PostClass 배열을 만들 때 없다는 뜻은 그 사이에 유저가 글을 올린 것도 되지만, 그런 일은 거의 하지 않을 것이다.
#		(물론 사용자를 정상인으로 보면 안된다는 철칙이 있지만... 일단 여기서 그 문제를 해결하기에 넘어가자.)
#		이 문제가 발생하는 이유는 글 목록에 해당 글이 없기에 발생한다.
#		따라서 새롭게 Post를 만든다.
#		이글루스가 닫았으니 글은 비공개, 댓글, 트랙백도 전부 닫기.

#		새로운 것 추가.
#		메뉴릿이라고 하는 것이 생겼는데 여기서 이런 일이 발생하고 있다.
		my %open_close;
		$open_close{post} = 'public';	# 메뉴릿이 더 많은 것이라 가정하자.
		$open_close{comment} = 0;
		$open_close{trackback} = 0;
		$open_close{datetime_info} = '';
		
		my $filename = 'data/' . $postid . '/content.xml';
		
#		post 변수 생성.
#		사실 이것 때문에 $egloosinfo을 가져와야한다.
#		그 전에는 필요한 것만 가져왔다.
#		중복되는 것을 제거하려고 하였으나 리팩토링이 귀찮아서 일단 이렇게 하였다.
		my $the_post = PostClass->new($postid, $egloosinfo, 0, 0, %open_close );
		
#		에러가 발생할 때는 이 comment를 그냥 넘기자.
#		넘기는 처리는 -1을 반환하는 것으로 하자.
		if(-1 == $the_post)
		{
			return -1;
		}
		
		# 메뉴릿인지 이글루스가 블라인드 한 것인지 확인한다.
		# 제목 옆에 잠금 표시가 있으면 비밀글이다.
		# <div class="subject"><h3><img src="http://md.egloos.com/img/eg/post_security.gif" width="13" height="16" align="absmiddle"/>
		my $private_icon_needle = '<div class="subject"><h3><img src="http://md.egloos.com/img/eg/post_security.gif" width="13" height="16" align="absmiddle"/>';
		if($the_post->{content_html} =~ m/$private_icon_needle/ig)
		{
			# 찾았기에 비밀글이다. 즉, 블라인드 한 글
			$the_post->{visibility} = 'private';
		}
		else
		{
			# 찾지 못했기에 메뉴릿이다.
			$the_post->{is_menu_page} = 1;
		}
		
#		xml 파일 쓰기.
		BackUpEgloos_Subs::write_post_xml($filename, $the_post);
		
#   	배열에 글 정보 저장.
		push @$all_post, $the_post;
		
#		배열 index 저장.
#		scalar함수를 쓰면 배열의 크기를 알 수 있다.
#		왜냐하면 @all_post만을 적으면 배열의 크기가 scalar 형태로 날아오기 때문이다.
#		자세한 것은 Perl 책을 참고하자.
		$postid_index->{$postid} = scalar(@$all_post) - 1;
		
#		유저에게 임시 조치한 글이 있음을 알리고, 따로 txt 파일로 만든다.
		BackUpEgloos_Subs::my_print("이글루스가 임시 조치한 글 혹은 메뉴릿을 추가하였습니다.\n" . "URL : " . $egloosinfo->{blogurl} . "/" . $postid . " - 제목 : " . $the_post->{title} . "\n");
#		>>으로 처리하여 기존의 글에 추가한다.
		open(OUT, ">>:encoding(utf8) " , 'Egloos_blind_or_menu.txt') or die $!;
		print OUT $postid . ' : ' .$the_post->{title} . "\n\n";
		close(OUT);
		
		$content = $all_post->[$postid_index->{$postid}]->{content_html};
	}
	
# 남은 것은 description, time
# 예제
#<div class="con">
#                        <span><a href="http://dongdm.egloos.com/m" target="_blank" class="nick">dongdm</a> <span>2010/01/16 13:57</span></span> 
#                        <p>
#
#                            댓글이에요~
#                            <a href="#;" onclick="delComment('a0030011', '2500689', '7537963', 'dongdm', '0', '1', '1');" class="btn_delete" title="삭제">삭제</a>
#                        </p>
#                        <div class="btn"><a href="#;" onclick="replyComment('7537963');" class="btn_reply" title="답글">답글</a></div>
#                    </div>
#
#<div class="con">
#                        <span><a href="http://naver.com" target="_blank" class="nick">ㅜㅒ뇨ㅕ</a> <span>7분전</span></span> 
#                        <p>
#
#                            ㅎㅎㅎㅎㅎ
#                            <a href="#;" onclick="delComment('a0030011', '2500689', '7977318.01', '', '1', '2', '1');" class="btn_delete" title="삭제">삭제</a>
#                        </p>
#                        
#                    </div>
	my $delete_needle = '<img src="http://md.egloos.com/img/mobile/ico_lock.gif" alt="비밀글" class="ico_lock" />';
	my $end_not_needle = "'" . $egloosinfo->{eid} . "', '" . $postid . "'";
	my $end_needle = "'" . $egloosinfo->{eid} . "', '" . $postid . "', '" . $commentid;
	$content =~ s/$delete_needle//ig;
	if($content =~ m/<span>(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})<\/span><\/span><p>((?:(?!delComment\($end_not_needle).)*?)<a href="#;" onclick="delComment\($end_needle/i)
	{
		#	있으니 가져오기	
		$time = DateTime->new(year => $1, month  => $2, day => $3,
						hour => $4, minute => $5, second => 0, time_zone => 'Asia/Seoul');	
		$description = $6;
		chomp($description);
	}
	else
	{
		# 본문에 얻기 힘드니 관리 페이지에서 가져오자.
		$comment_field =~ m/<td width="80" align="center" class="black">(\d{4})\/(\d{2})\/(\d{2})<\/td><\/tr>/i;
		$time = DateTime->new(year => $1, month  => $2, day => $3,
						hour => 0, minute => 0, second => 0, time_zone => 'Asia/Seoul');
						
		$comment_field =~ m/<td width="395" class="black"><a href="[^"]+" title="(.*?)" target="_new">(?:.*?)<\/a>/i;
		$description = $1;
		
		BackUpEgloos_Subs::my_print("댓글 시각을 제대로 가져오지 못했기에 관리 페이지에 있는 정보로만 입력합니다.\n" . "URL : " . $egloosinfo->{blogurl} . "/" . $postid . '#' . $commentid . "\n");
	}
	$time = $time->epoch();
	
	# 이런 태그를 처리하는 함수가 있을 것으로 추정되나 찾을 수 없음.
	#	&quot; -> "
		$description =~ s/&quot;/"/ig;
	#	&lt; -> <
		$description =~ s/&lt;/</ig;
	#	&gt; -> >
		$description =~ s/&gt;/>/ig;
	#	&amp; -> &
		$description =~ s/&amp;/&/ig;

#	저장할 변수를 hash로 만든다.
#	여기에 대해서 NoSyu도 가르쳐 줄만큼 명확하게 이해하지 않았기에 코드를 생략한다.
#	다만, Package에서 변수 등록을 이렇게 하는 것이고, 좀 더 자세한 것은 Perl 책을 참조하기를 바란다.
	my $self = { is_root => $is_root, description => $description,
		time => $time, is_secret=>$is_secret, href=>$href, who=>$who,
		postid=>$postid, id=>$postid . '#' . $commentid };
	bless ($self, $class);
	
	return $self;
}

1;