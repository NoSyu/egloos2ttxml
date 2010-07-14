# 2009-1-13

package PostClass;

use warnings;
use strict;
use Carp;
use RPC::XML; # 글 정보를 가져오는 방법으로 XML-RPC를 사용하였음. 그와 관련된 라이브러리.
use RPC::XML::Client; # 글 정보를 가져오는 방법으로 XML-RPC를 사용하였음. 그와 관련된 라이브러리. 그 중에서 클라이언트만 필요하기에 이것을 지정.
use DateTime; # 글이 쓰여진 시간이 Unix 시간으로 TTXML에 기록되기에 이를 사용한다.
use utf8; # 이글루스 정보들은 encoding으로 utf8으로 되어있기에 사용.

my $postid; # 글 아이디 - TTXML : id, 하지만 여기서는 이글루스의 id가 들어간다.
my $description; # 본문 - TTXML : content
my $time; # 시간 - TTXML : published, created, modified
my $title; # 제목 - TTXML : title
my $link; # 주소 - 이글루스 원본 글의 주소.
my $category; # 카테고리 - TTXML : category
my $trackback_count; # trackback 개수
my $comment_count; # comment 개수
#my $pingback_count; # ping 개수 # Textcube에서는 핑백이 존재하지 않기에 이를 처리하지 않습니다.
my $visibility; # 공개여부. private : 비공개, public : 공개.
my $acceptComment; # 덧글을 받아들일 수 있는지... 0 : 안됨. 1 : 받을 수 있음.
my $acceptTrackback; # 트랙백을 받아들일 수 있는지... 0 : 안됨. 1 : 받을 수 있음.
my $file_count; # 본문 안 파일 개수. 이미지 파일 포함. 폴더에 저장될 때 숫자로 저장됨.
# Trackback과 Comment 배열은 다 받고나서 id별로 정렬된다.
# postid별로 저장된다는 보장은 없지만, 그 안에서는 각자의 id별로 정렬이 보장된다.
# 이글루스에서는 root 댓글 혹은 트랙백이 날아온 순서대로 각자 id를 오름차순으로 할당하였기에 이렇게 하면 시간을 따질 필요없이 얻을 수 있다.
# 따라서 각 글이 자신의 트랙백과 댓글의 처음과 끝의 배열 index를 안다면 필요할 때 마다 일일이 찾을 필요가 없어진다.
# 나름 최적화를 위해서 머리를 쓴 결과이다.
# 좀 더 좋은 방법이 있다면 제안 혹은 수정해주기를...
# 트랙백 배열에서 시작과 끝.
my $start_trackbacks = -1;
my $end_trackbacks = -1;
# 댓글 배열에서 시작과 끝.
my $start_comments = -1;
my $end_comments = -1;
my $content_html; # content html 저장. - 2009-1-11 추가.
# 기존에는 댓글과 트랙백 하나마다 글이 적혀진 페이지에 접근하였으나 이글루스에서 접속을 끊어버려 그리고 네트워크 사용으로 프로그램 속도가 느려짐.
# 따라서 글에 대한 정보를 저장할 때 가공하지 않은 html 코드를 저장하기로 함.
# 대신 페이지 전부가 아닌 글, 트랙백, 댓글이 있는 부분만 저장한다.

#생성자
sub new ($$$\%%)
{
	my $class = shift;
	# post id, 이글루스 정보, 기존에 받은 것인가 아니면 받아야 하는가?, 기존에 받은 것이면 그 데이터, 글-댓글-트랙백 공개여부
	my ($postid, $egloosinfo, $new_type, $content_all, %open_close) = @_;
	my $self;
	
#	이글루스에서 접근하여 새롭게 만들기.
	if(0 == $new_type)
	{
#		파일 카운트 변수 초기화.
		$file_count = 0;
		
#		글 정보 얻기.	
#		여기서 이글루스가 접속을 끊어버리면 바로 죽어버림.
#		아마 이것도 내가 예외를 처리할 수 있게 만들어져 있을 것이다.
#		일단 지금은 처리하지 않음.
#		xmlrpc를 이용해서 글을 가져옴.
#RPC_XML_START:
		my $cli = RPC::XML::Client->new($egloosinfo->{apiurl});
#		$postid, $egloosinfo->id, $egloosinfo->apikey
		my $req = RPC::XML::request->new('metaWeblog.getPost', $postid, $egloosinfo->{id}, $egloosinfo->{apikey});
		my $resp = $cli->send_request($req);
		# 날아온 값이 에러인지 아닌지 판단
		# 버그 리포트에 따르면 NULL이 날아옴.
		# BackUpEgloos_Subs::my_print($resp . "\n");
		# 웹페이지의 자료를 가져옴.
		my $content = BackUpEgloos_Subs::getpage($egloosinfo->{blogurl} . '/' . $postid, 0);
		# 파일이 존재하지 않기에 페이지 접근.
		# <!-- egloos content start -->(.*?)<!-- egloos content end -->
		if($content =~ m/<!-- egloos content start -->(.*?)<!-- egloos content end -->/ig)
		{
			$content_html = $1;
		}
		# 스킨 2.0
		elsif($content =~ m/<div class="body">(.*?)<div class="post_navi">/ig)
		{
			$content_html = $1;
		}
		else
		{
			$content_html = $content;
		}
		
		# XMLRPC 에러 여부 조사
		if(! ref $resp || $resp->is_fault())
		{
			# 에러가 난 것임
			BackUpEgloos_Subs::my_print("에러! : XMLRPC로 " . $postid ."의 글을 가져오는데 에러가 났습니다.\n");
			# 예전 것. 이 방법으로도 해결이 되지 않음.
			#BackUpEgloos_Subs::my_print("에러로 인해 10초 후 다시 접근을 시도합니다.\n" . '이 문구가 계속 나타나면 스크린샷을 찍은 후 Ctrl+C를 눌러 프로그램을 종료시키세요.' . "\n");
			# 제대로 되지 않았으니 10초 후 다시 시도
			#sleep 10;
			# 다시 시도
			# goto인 것이 마음에 들지 않으나 한 눈에 보이는 것이니 스파게티가 되지 않을 것임.
			# 다르게 바꾸고 싶다면 바꿔도 무방.
			#goto RPC_XML_START;
			
			# 그냥 웹페이지에서 가져오자.
			BackUpEgloos_Subs::print_txt("에러로 인해 " . $postid ."의 글을 XMLRPC가 아닌 웹페이지에서 자료를 가져옵니다.\n");
			
			# 변수 할당.
			$title = BackUpEgloos_Subs::findstr($content_html, '<div class="post_title">(?:.*?)<a[^>]+?>', '<\/a>');
			$link = $egloosinfo->{blogurl} . '/' . $postid;
			$description = BackUpEgloos_Subs::findstr($content_html, "<div class='hentry'><span[^>]+?><\/span>", '[ ]*?<!--[ ]*?<rdf:RDF');
			# 이런 태그를 처리하는 함수가 있을 것으로 추정되나 찾을 수 없음.
			#	&quot; -> "
			#	$description =~ s/&quot;/"/ig;
			#	&lt; -> <
			#	$description =~ s/&lt;/</ig;
			#	&gt; -> >
			#	$description =~ s/&gt;/>/ig;
			#	&amp; -> &
			#	$description =~ s/&amp;/&/ig;
			if($content_html =~ m/<span class="post_title_category"><a[^>]+?>(.*?)<\/a>/ig)
			{
				$category = $1;
			}
			else
			{
				$category = '미분류';
			}
			# 2010/07/08 22:29
			$time = BackUpEgloos_Subs::findstr($content_html, '<abbr class="published" title="', '">');;
			$time =~ /(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})/i;
			$time = DateTime->new(year => $1, month  => $2, day => $3,
					hour => $4, minute => $5, second => 0, time_zone => 'Asia/Seoul');
			$time = $time->epoch();
		}
		else
		{
			# 에러가 나지 않았기에 처리
			# XMLRPC를 사용하여 가져옴
			my %result = %{$resp->value()};
			
	#		잘못된 경우 에러를 출력하도록 한다.
	#		대표적으로 잘못된 postid가 날아왔을 경우가 있다.
	#		에러가 나면 -1을 반환하자.
			if(exists $result{faultString})
			{
				BackUpEgloos_Subs::my_print("에러! : " . $postid ."의 글을 가져오는데 에러가 났습니다.\n");
				BackUpEgloos_Subs::my_print('error.txt를 nosyu@nosyu.pe.kr으로 보내주시길 바랍니다.' . "\n");
				BackUpEgloos_Subs::print_txt('faultString : ' . $result{faultString} . " \nfaultCode : " . $result{faultCode} . "\n");
				return -1;
			}
			
	#		XML-RPC를 통해 받은 정보에 따라 변수 할당.
			$title = $result{title};
			$link = $result{link};
			$postid = $result{postid};
			$description = $result{description};
			$category = @{$result{categories}}[0];
			
	#	&quot; -> "
			$title =~ s/&quot;/"/ig;
		
			# 시간은 받고나서 TTXML 형태에 맞춰 처리.
			$time = $result{dateCreated}; # 20070809T13:39:56
			$time =~ /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/i;
			# 시간이 리눅스와 윈도우에서 가져오는 폼이 다르다.
			if(!$6)
			{
				$time =~ /(\d{4})(\d{2})(\d{2})T(\d{2}):(\d{2}):(\d{2})/i;
				$time = DateTime->new(year => $1, month  => $2, day => $3,
						hour => $4, minute => $5, second => $6, time_zone => 'Asia/Seoul');
			}
			else
			{
				$time = DateTime->new(year => $1, month  => $2, day => $3,
						hour => $4, minute => $5, second => $6, time_zone => 'Asia/Seoul');
			}
			$time = $time->epoch();
		}
		#BackUpEgloos_Subs::my_print("$title\n$link\n$description\n$category\n$time\n");
		
#		글 공개여부.
		$visibility = $open_close{post};
#		트랙백, 댓글 공개여부. 
		$acceptComment = $open_close{comment};
		$acceptTrackback = $open_close{trackback};
		
#		postid로 디렉토리 만들기. - 있는 경우 처리.
		if(!(-e './data/' . $postid))
		{
			mkdir('./data/' . $postid) or die "폴더 만들기 에러.\n";
		}
		

#		트랙백 개수 가져오기.
#		<span class="linkback">트랙백(<span id="trbcnt4046501">1</span>)
		if($content_html =~ m/<span class="linkback">트랙백\(<span [^>]+>(.*?)<\/span>\)/i)
		{
			$trackback_count = $1;
		}
		# 스킨 2.0
		# <a class="post_tail_trbk">트랙백(<span id="trbcnt2500689" class="count">2</span>)</a>
		elsif($content_html =~ m/<a class="post_tail_trbk">트랙백\(<span [^>]+>(.*?)<\/span>\)/i)
		{
			$trackback_count = $1;
		}
		else
		{
			$trackback_count = 0;
		}
		
#		댓글 개수 가져오기.
#		<span class="linkback">덧글(<span id="cmtcnt4794508">10</span>)
		if($content_html =~ m/<span class="linkback">덧글\(<span [^>]+>(.*?)<\/span>\)/i)
		{
			$comment_count = $1;
		}
		# 스킨 2.0
		# <a class="post_tail_cmmt"> 덧글(<span id="cmtcnt2500689" class="count">4</span>)</a>
		elsif($content_html =~ m/<a class="post_tail_cmmt"> 덧글\(<span [^>]+>(.*?)<\/span>\)/i)
		{
			$comment_count = $1;
		}
		else
		{
			$comment_count = 0;
		}
		
		
#		이전 댓글이 있는지 확인하여 있으면 content_html에 추가한다. - 2009-1-13
#		즉, 한 글에 댓글 100개 이상이면 이글루스는 댓글의 내용을 잘라서 보여준다.
#		따라서 이를 해결하고자 이 방법을 사용한다.
#		개인적으로 상당히 오래 걸릴 것이라 생각했으나 의외로 너무 쉬워서 허무했던 기능.
#		예제.
#		"/egloo_comment.php?eid=" + eid + "&srl=" + serial + "&xhtml=" + xhtml + "&adview=0&page=" + page + "&ismenu=" + ismenu;
#		http://nightstar.egloos.com/egloo_comment.php?eid=b0006600&srl=3668037&xhtml=1&adview=0&page=2&ismenu=0
#		cmtview_more('3668037','b0006600','1',2, 0, this); return false;">이전 덧글 100개 더보기
#		cmtview_more(\'3668037\',\'b0006600\',\'1\',3, 0, this);
#		예제.
#		<a href="#" onclick="cmtview_more('3668037','b0006600','1',2, 0, this); return false;">이전 덧글 100개 더보기</a>
#		댓글의 개수가 100개 이상이면...
		if($comment_count > 100)
		{
			my $comments_html = $content_html;
			
			# 예전 것.
			if($comments_html =~ m/<a href="#" onclick="cmtview_more\('$postid','$egloosinfo->{eid}','1',(\d{1,2}), 0, this\); return false;">이전 덧글/i)
			{
				while($comments_html =~ m/<a href="#" onclick="cmtview_more\('$postid','$egloosinfo->{eid}','1',(\d{1,2}), 0, this\); return false;">이전 덧글/i)
				{
	#				이전 댓글이 존재한다.
	#				가져오기.
					my $comments_src = $egloosinfo->{blogurl} . '/egloo_comment.php?eid=' . $egloosinfo->{eid} . '&srl=' . $postid . '&xhtml=1&adview=0&page=' . $1 . '&ismenu=0';
					$comments_html = BackUpEgloos_Subs::getpage($comments_src, 0);
					
	#				이상한 것 제거.
	#				아마도 DB에 저장할 때 escape 문자를 처리하는 함수를 돌려 저장한 후, 이를 가져올 때는 그것들을 제거하지 않은 듯싶다. 따라서 여기서 제거한다.
					$comments_html =~ s/\\"(.*?)\\"/"$1"/ig;
					$comments_html =~ s/\\'(.*?)\\'/'$1'/ig;
					
	#				붙이기.
	#				기존의 것과 연결해서 붙여넣기.
					$content_html = $content_html . $comments_html;
				}
			}
			# 스킨 2.0
			# http://dongdm.egloos.com/egloo_feedback.php?eid=a0030011&ismain=&page=2&srl=2500684&type=post_comment&xhtml=1
			else
			{
				my $comments_html;
				my $comment_count_i = $comment_count;
				my $cmt_page = 2;
				my $comments_src = $egloosinfo->{blogurl} . '/egloo_feedback.php?eid=' . $egloosinfo->{eid} . '&ismain=&type=post_comment&xhtml=1&srl=' . $postid . '&page=';
				
				while($comment_count_i > 100)
				{
					# 가져오기.
					$comments_html = BackUpEgloos_Subs::getpage($comments_src . $cmt_page, 0);
					
					# 이상한 것 제거.
					# 아마도 DB에 저장할 때 escape 문자를 처리하는 함수를 돌려 저장한 후, 이를 가져올 때는 그것들을 제거하지 않은 듯싶다. 따라서 여기서 제거한다.
					$comments_html =~ s/\\"(.*?)\\"/"$1"/ig;
					$comments_html =~ s/\\'(.*?)\\'/'$1'/ig;
					
					# 붙이기.
					# 기존의 것과 연결해서 붙여넣기.
					$content_html = $content_html . $comments_html;
					
					# 루프 다음 것 처리.
					$comment_count_i -= 100;
					$cmt_page++;
				}				
			}
		}
		
#		xml에 쓸 수 없는 글자가 있는 경우 일단 점으로 바꾼다.
#		밑의 코드는 XML::Writer에서 가져온 것이다. 여기에서 에러를 일으키기에 그 아이디어를 가져왔다.
# XML\Writer.pm 767~773
# Enforce XML 1.0, section 2.2's definition of "Char" (only reject low ASCII,
#  so as not to require Unicode support from perl)
#sub _croakUnlessDefinedCharacters($) {
#  if ($_[0] =~ /([\x00-\x08\x0B-\x0C\x0E-\x1F])/) {
#    croak(sprintf('Code point \u%04X is not a valid character in XML', ord($1)));
#  }
#}
#		유니코드 0x25CF는 점을 뜻한다.
		$content_html =~ s/[\x00-\x08\x0B-\x0C\x0E-\x1F]/\x{25CF}/g;
		
		
#		이미지 다운로드 받기.
#		이미지 다운로드 및 파일 다운로드 그리고 이름 변경까지 수행한다.
		$description = changeimgsrc($description, $postid);
		
#		변수 등록.
		$self = { postid=>$postid, description=>$description, time=>$time,
		title=>$title, link=>$link, category=>$category,
		visibility=>$visibility,
		acceptComment=>$acceptComment, acceptTrackback=>$acceptTrackback,
		file_count=>$file_count,
		start_trackbacks=>$start_trackbacks, end_trackbacks=>$end_trackbacks,
		start_comments=>$start_comments, end_comments=>$end_comments,
		trackback_count=>$trackback_count, comment_count=>$comment_count,
		content_html=>$content_html};
	}
#	파일이 존재하니 불러오기.
#	즉, 이미 다운로드를 받았기에 새롭게 다운로드를 받을 필요가 없다는 뜻임.
	else
	{
#		self가 hash 형식이기에 혹시나하는 생각에 이렇게 해보니 제대로 작동하였음.
		$self = $content_all;
	}
	
	bless ($self, $class);
	
	return $self;
}


# 포스트 안의 img 태그에 있는 src를 바꾼다.(다운로드 받아서)
# 이미지 뿐만 아니라 zip, pdf도 처리한다.
sub changeimgsrc($$)
{
#	본문 안의 내용, post id 
	my ($description, $postid) = @_;
	# 다운로드 받아 저장할 src : 'pic/postid_XXX.jpg(png 등)'

	my $i = 1; # 다운로드 받은 것들의 이름. 1부터 시작
	my $ori_post_html = $description; # 원본 페이지.
	
	
	# 본문 안의 이미지 다운로드
	while($description =~ m/<img ((?:.*?) src="(http:\/\/[[:alnum:][:punct:]^>^<^"^']+\.(jpg|png|gif|jpeg))"[^>]*)>/igc)
	{
#		예제.
#		http://pds12.egloos.com/pds/200812/29/60/c0049460_495826383bef7.png
#		$img_url = http://pds12.egloos.com/pds/200812/29/60/c0049460_495826383bef7.png
#		$img_extension = png
		my $img_info_html = $1; # 그림 정보.
		my $img_url = $2; # 그림 url
		my $img_extension = $3; # 그림 파일 확장자
		my $width; # 그림 넓이.
		my $height; # 그림 높이.
		my $alt; # 그림 설명.
		
#		width, height, alt 추출.
#		없을 경우 ''으로 처리.
		if($img_info_html =~ m/width="(.+?)"/i)
		{
			$width = $1;
		}
		else
		{
			$width = '';
		}
		if($img_info_html =~ m/height="(.+?)"/i)
		{
			$height = $1;
		}
		else
		{
			$height = '';
		}
		if($img_info_html =~ m/alt="(.*?)"/i)
		{
			$alt = $1;
		}
		else
		{
			$alt = '';
		}
		
#		이미지 저장할 경로 설정.
		my $istr = BackUpEgloos_Subs::numtonumstr($i);
		my $img_dest = 'data/' . $postid . '/' . $istr . '.' . $img_extension;
#		다운로드.
		if(-1 == BackUpEgloos_Subs::downImage($img_url, $img_dest, 0))
		{
#			에러가 발생한 것임.
#			2009.1.22
			BackUpEgloos_Subs::print_txt('이미지 다운로드 에러 : ' . $img_url . ' 글 : ' . $postid . "\n하지만 프로그램은 계속 진행됩니다.");
		}
		else
		{
			# 문제 없기에 본문 안의 내용 바꾸기.
			# 페이지 안의 주소 수정
	#		XML 파일에 적기위해 치환자 설정.
	#		예제.
	#		[##_1C|1044461297.png|width="490" height="88.1072555205" alt=""| _##]
			my $img_info = 'width="' . $width .
							'" height="' . $height .
							'" alt="' . $alt . '"';
			$img_dest = '[##_1C|' . $istr . '.' . $img_extension . '|' . $img_info . '| _##]'; # TTXML에 맞게 이름 설정.
			$ori_post_html =~ s/<img (?:.*?) src="$img_url"[^>]*>/$img_dest/ig; # 이름 바꾸기.
			$i++; # 파일명을 하나 증가.
		}
	} # end of  foreach my $img_elem (@img_elems)
	
#	zip, pdf 파일 받기.
	while($description =~ m/"(http:\/\/[[:alnum:][:punct:]^>^<^"^']+\.(pdf|zip))"/igc)
	{
#		예제.
#		<a href="http://pds12.egloos.com/pds/200901/09/01/HW1334.zip">HW1334.zip</a>
		my $file_url = $1; # 파일 url
		my $file_extension = $2; # 파일 확장자
		
#		파일 저장할 경로 설정.
		my $istr = BackUpEgloos_Subs::numtonumstr($i);
		my $file_dest = 'data/' . $postid . '/' . $istr . '.' . $file_extension;
#		다운로드.
		if(-1 == BackUpEgloos_Subs::downImage($file_url, $file_dest, 0))
		{
#			에러가 발생한 것임.
#			2009.1.22
			BackUpEgloos_Subs::print_txt('파일 다운로드 에러 : ' . $file_url . ' 글 : ' . $postid . "\n하지만 프로그램은 계속 진행됩니다.");
		}
		
		
# 		페이지 안의 주소 수정
#		XML 파일에 적기위해 치환자 설정.
#		예제.
#		[##_1C|Xaxm6sRB1x.PDF||_##]
		$file_dest = '[##_1C|' . $istr . '.' . $file_extension . '|| _##]'; # TTXML 설정에 맞춤.
		$ori_post_html =~ s/<a href="$file_url">(?:.*?)<\/a>/$file_dest/ig; # 바꾸기.
		$i++; # 파일 이름 증가.
	}
	
	$file_count = $i-1; # 파일 개수 지정.
	return $ori_post_html; # 이미지 주소를 바꾼 본문 내용을 반환.
}


1;