# 2009-1-13

package BackUpEgloos_Subs;

use warnings;
use strict;
use Carp;
# 이글루스 백업 프로그램 패키지들.
use CommentClass;
use TrackbackClass;
use PostClass;
#use PostClass_m;

# cpan 라이브러리.
use WWW::Mechanize;  # 웹페이지에 접근하는 아주 훌륭한 라이브러리.
use Digest::Perl::MD5 'md5_base64'; # 암호를 만들 때 쓰임.
use utf8; # 이글루스 정보들은 encoding으로 utf8으로 되어있기에 사용.
use File::Util; # 파일 접근용 라이브러리.
use MIME::Base64; # 첨부파일(이미지, pdf, zip등.)을 TTXML에 넣을 때 base64 encoding을 써야함.
use Encode; # Windows 명령 프롬프트는 utf8이 기본이 아니라 이를 변경해아함.
#use XML::Simple; # 이것을 선택하였으나 unicode 처리가 부적절하고, 속도도 느려 밑의 것을 선택.
use XML::LibXML::Simple   qw(XMLin); # 위의 이유로 이것을 선택함.
use IO::File; # File 입출력.
use XML::Writer; # xml 작성 라이브러리.
#use WordPress::XMLRPC; # editpost 때 쓰이는 라이브러리.

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
login_egloos
getpage
downImage
numtonumstr
findstr
print_txt
write_comments
write_trackbacks
write_post
BackupPhotolog
editpost
get_all_list
get_all_post
get_all_trackback
get_all_comment
my_print
writeTTXML
);

use vars qw(@print_text);

# function declation.
# 원래 이 패키지는 다른 곳에서 쓰는 함수를 모은 것이라 따로 하지 않았으나, 이 안에서 쓰이는 함수들이 순서에 맞지 않게 존재하여 이렇게 선언하였음.
# 물론 선언과 정의를 따로 하는 것이 좋은 코딩이나 이번에는 그렇게 하지 않았기에(이유는 Perl에서는 그럴 필요가 없다고 생각했기에... 물론 틀린 얘기다.) 그것에 따라 그대로 처리하였다.
sub getpage ($$);
sub downImage ($$$);
sub print_txt ($);

# 로그인 함수.
# 실제로 EgloosInfo에서만 처음에 호출되는 함수이기에 거기에 만들어서 사용하는 것이 좋으나, 전역변수로서 $EgloosInfo::mech가 제대로 작동하는지 확인하고자 여기에 만들었고, 잘 작동하시에 리팩토링을 하지 않고 그대로 사용하게 되었음.
# EgloosInfo 패키지에 넣고 싶다면 언제라도 넣어도 되는 함수.
sub login_egloos ($$)
{
	my ($id, $pw) = @_;
	#my $loginpage = 'http://www.egloos.com/login.php';
	my $loginpage = 'http://www.egloos.com';
	
#	WWW::Mechanize 라이브러리는 form 형식에 맞게 submit을 지원하기에 아주 쉽게 만들 수 있음.
#	물론 이 방법이 아니고 무식하게 POST 방식으로 아이디와 비밀번호를 전달하여 로그인을 처리하는 php에 접속하여 로그인하는 방법도 가능하다.
#	다만, 이것이 좀 더 깔끔해 보이기에 이렇게 처리하였다.
#	이 함수 이후로 $EgloosInfo::mech는 로그인 된 쿠키(세션?)을 가지게 되어, 비밀글과 비밀댓글을 볼 수 있다.
	$EgloosInfo::mech->get($loginpage);
	
	#$EgloosInfo::mech->submit_form(
	#form_name => "login",
	#fields => {
#		userid => $id, 
#		userpwd => $pw},
#	button => 'lbtn');
	$EgloosInfo::mech->submit_form(
	form_name => "authform",
	fields => {
		userid => $id, 
		userpwd => $pw},
	button => 'lbtn');
	
	# 로그인이 제대로 되었는지 확인
	#my $login_ok_url = 'https://www.egloos.com/login/login_ok.php?reurl=http://www.egloos.com';
	my $result_url = $EgloosInfo::mech->uri()->as_string;
	if($result_url =~ m/errorno/ig)
	{
		my_print("로그인 에러... 아이디와 비밀번호를 확인하세요.\n");
		die;
	}
	else
	{
		return;
	}
}


# URL을 받아서 해당 URL에 접속하여 그 내용을 반환하는 함수.
sub getpage ($$)
{
	my ($pageurl, $times) = @_;
	my $content;
	
#	페이지에 접근하여
#	2009.1.22
	$EgloosInfo::mech->get($pageurl);
	if(200 == $EgloosInfo::mech->status())
	{
#		status가 200이라는 말은 제대로 접속했다는 뜻이다.
#		페이지를 변수에 저장
		$content = $EgloosInfo::mech->content();
		
# 		공백 없애기
		$content =~ s/[\n\r\t]//g;
		$content =~ s/>( )+</></g;
		
#		반환
		return $content;
	}
	else
	{
		if($times < 3)
		{
			#		제대로 된 접속이 되지 않으면 10초 후 다시 시도한다.
			my_print("에러로 인해 10초 후 다시 접근을 시도합니다.\n" . '이 문구가 계속 나타나면 스크린샷을 찍은 후 Ctrl+C를 눌러 프로그램을 종료시키세요.' . "\n");
			#print_txt($pageurl);
			# 제대로 되지 않았으니 10초 후 다시 시도
			sleep 10;
			# 다시 시도
			return getpage($pageurl, $times + 1);
		}
		else
		{
			# 계속된 시도에도 안 된다면 이건 문제가 있음.
			my_print("에러로 인해 더 이상의 접근이 되지 않습니다.\n" . '문제가 계속될 수 있으니 10분 가량 후에 다시 프로그램을 실행해보세요.' . "\n");
			die;
		}
	}
}


# 본문의 이미지를 가져오는 함수
sub downImage ($$$)
{
#	이미지의 URL, 이미지를 저장하는 곳.
	my ($img_src, $img_dest, $times) = @_;
	
#	이미 파일이 존재하면 -2을 리턴.
	if(-e $img_dest)
	{
		return -2;
	}
#	파일 다운로드 받기.
	else
	{
#	2009.1.22
		$EgloosInfo::mech->get($img_src);
		if(200 == $EgloosInfo::mech->status())
		{
			#if()
			#{
				
			#}
			my $ctr = $EgloosInfo::mech->content_type();
			#print_txt($ctr);
#			status가 200이기에 정상이니까 저장한다.
			$EgloosInfo::mech->save_content($img_dest);
			return 0;
		}
		elsif(404 == $EgloosInfo::mech->status())
		{
#			status가 404라는 말은 해당 그림이 존재하지 않는다는 뜻이다. 즉, 서버측에서 해당 이미지를 지웠을 가능성이 높다.
#			따라서 해당 URL이 잘못되었음을 txt 파일로 저장한 다음에 -1을 반환한다.
#			이것으로 이 함수를 호출한 함수가 에러를 처리할 수 있도록 돕는다.
			#print_txt($img_src);
			return -1;
		}
		else
		{
			if($times < 3)
			{
#				재시도
				my_print("그림 파일 다운로드 에러로 인해 10초 후 다시 접근을 시도합니다.\n" . '이 문구가 계속 나타나면 스크린샷을 찍은 후 Ctrl+C를 눌러 프로그램을 종료시키세요.' . "\n");
				# 제대로 되지 않았으니 10초 후 다시 시도
				sleep 10;
				# 다시 시도
				
				return downImage($img_src, $img_dest, $times + 1);
			}
			else
			{
				# 그냥 에러 처리
				return -1;
			}
		}
	}
}


# 숫자를 4자리의 문자열로 만드는 함수.
# 자동으로 이런 함수가 있으면 좋겠으나 (아마도 있지 않을까 싶다.) 일단 이렇게 무식하게 만들었음.
# Perl에서는 숫자와 문자열의 경계가 모호하기에 상당히 편하게 만들 수 있다.
sub numtonumstr($)
{
#	번호를 받아
	my $img_num = shift;
	
#	10보다 작으면 000을 붙이고,
	if($img_num < 10)
	{
		return '000' . $img_num;
	}
#	10보다 크고 100보다 작으면 00을 붙이고,
	elsif($img_num < 100)
	{
		return '00' . $img_num;
	}
#	100보다 크고 1000보다 작으면 0을 붙이고,
	elsif($img_num < 1000)
	{
		return '0' . $img_num;
	}
#	그렇지 않으면 그대로 반환한다.
	else
	{
		return  $img_num;
	}
}


# 문자열 찾기
# 찾으면 해당 문자열을, 못 찾으면 -1을 리턴한다.
sub findstr ($$$)
{
#	내용물들, 찾아야 할 문자열의 앞에 있는 것, 찾아야 할 문자열의 뒤에 있는 것.
	my ($content, $needle1, $needle2) = @_;
	
	if($content =~ m/$needle1(.*?)$needle2/ig)
	{
#		찾았기에 찾은 내용물을 반환.
		return $1;
	}
	else
	{
#		찾지 못하였기에 -1을 반환.
		return -1;
	}
}


# 에러를 txt 파일로 출력
sub print_txt ($)
{
	my $result = shift;
	
#	처음에는 프로그래밍을 할 때 디버깅 코드로 만들었으나 후에는 유저들에게서 리포트를 받을 때도 쓰게 되었음.
#	따라서 조금 이상한(부족한) 감이 있음.
#	보강이 필요한 함수 중 하나.
#	txt 파일을 만들 때 time 함수를 넣어서 중복이 되는 경우가 없도록 만들었음.
	open(OUT, ">:encoding(utf8) " , 'error_' . time . '.txt') or die $!;
	print OUT $result . "\n\nPrint Screen\n";
#	화면에 뿌리는 메시지를 저장한 @print_text 변수를 출력함.
	foreach (@print_text)
	{
		print OUT $_;
	}
	close(OUT);
}


# xml파일에 post 들을 적는 함수.
# main.pl에서 이 함수를 호출하여 post들을 xml 파일에 적는다.
sub write_post ($$$$\@\@\%)
{
#	이글루스 정보, 처리해야 할 post(PostClass form), xml을 적을 수 있는 핸들러, Textcube에서 쓰일 post id, trackback 들, comment들, post 배열을 추적할 수 있는 hash table  
	my ($egloosinfo, $the_post, $xml_writer,
		$id, $all_trackback, $all_comment, $postid_index) = @_;
	
	# 메세지 출력
	my_print("URL : " . $egloosinfo->{blogurl} . "/" . $the_post->{postid} . " - 제목 : " . $the_post->{title} . "\n");
	
	# ----------------------------------------------------------------------------- #
	#	xml에 Post 태그를 시작합니다.
	# ----------------------------------------------------------------------------- #
	# Post 태그 시작하기
	$xml_writer->startTag("post", "slogan" => $the_post->{title});
	
	# ----------------------------------------------------------------------------- #
	#	Post 제목과 내용 등을 처리합니다.
	#	댓글과 트랙백은 밑에서 처리합니다.
	# ----------------------------------------------------------------------------- #
	# title : 제목
	$xml_writer->startTag("title");
	$xml_writer->characters($the_post->{title});
	$xml_writer->endTag("title");
	
	# id : 글의 번호
	$xml_writer->startTag("id");
	$xml_writer->characters($id);
	$xml_writer->endTag("id");
	
	# visibility : 공개여부
	$xml_writer->startTag("visibility");
	$xml_writer->characters($the_post->{visibility});
	$xml_writer->endTag("visibility");
	
	# location : 지역 태그 - 이글루스에는 이런 태그가 없음.
	$xml_writer->startTag("location");
	$xml_writer->characters('/');
	$xml_writer->endTag("location");
	
	# password : 비밀번호 라고 해석되나 정확하게 무엇인지 모름. 역시 이글루스에는 없음.\
	# 그렇다고 아무거나 넣으면 쉽게 뚫릴 듯싶어 그것은 좋지 않다고 판단.
	# 그래서 그냥 현재 시각을 인자로 하여 md5 함수를 돌린 값을 넣었음.
	# 그러하여도 삭제나 수정은 잘 되는 것을 확인.
	$xml_writer->startTag("password");
	$xml_writer->characters(md5_base64(time));
	$xml_writer->endTag("password");
	
	# acceptComment : 댓글을 적을 수 있는지인지... 여튼 비슷한 것인 듯싶다.
	$xml_writer->startTag("acceptComment");
	$xml_writer->characters($the_post->{acceptComment});
	$xml_writer->endTag("acceptComment");
	
	# acceptTrackback : 트랙백을 적을 수 있는지인지... 여튼 비슷한 것인 듯싶다.
	$xml_writer->startTag("acceptTrackback");
	$xml_writer->characters($the_post->{acceptTrackback});
	$xml_writer->endTag("acceptTrackback");
	
	# published : 글을 발행한 날짜.
	# 이글루스의 경우 이 차이를 두지 않기에 created와 modified도 동일하게 한다.
	$xml_writer->startTag("published");
	$xml_writer->characters($the_post->{time});
	$xml_writer->endTag("published");
	
	$xml_writer->startTag("created");
	$xml_writer->characters($the_post->{time});
	$xml_writer->endTag("created");
	
	$xml_writer->startTag("modified");
	$xml_writer->characters($the_post->{time});
	$xml_writer->endTag("modified");
	
	# category : 카테고리
	$xml_writer->startTag("category");
	$xml_writer->characters($the_post->{category});
	$xml_writer->endTag("category");
	
	# tag : 태그 - 있는 만큼 태그로 만든다.
	# <ul class="tag"><li><a href="/m/tag/%ED%83%9C%EA%B7%B8">태그</a></li><li><a href="/m/tag/%ED%83%9C%EA%B7%B81">태그1</a></li><li class="last"><a href="/m/tag/%ED%83%9C%EA%B7%B82">태그2</a></li></ul>
	my @tags; # 태그.
	# 본문 부분 가져오기
	my $page = $the_post->{content_html};
	if($page =~ m/<ul class="tag">(.+?)<\/ul>/g)
	{
		my $tag_html = $1;
		# 예제 : 주민등록번호,&nbsp;도용,&nbsp;탈퇴,&nbsp;웹사이트,&nbsp;사이트
		$tag_html =~ s/<li(?:[^>]*)><a href="[^"]+">(.*?)<\/a><\/li>/$1<>/ig;
		@tags = split /<>/, $tag_html;
		
		# tags 변수 안에 있는 것을 xml에 하나씩 쓰기.
		foreach (@tags)
		{
			$xml_writer->startTag("tag");
			$xml_writer->characters($_);
			$xml_writer->endTag("tag");
		}
	}
	
#	본문 안의 자신의 블로그 주소를 새로운 것으로 바꿈.
	if(!('' eq $egloosinfo->{newblogurl}))
	{
		if($the_post->{description} =~ m/$egloosinfo->{blogurl}\/(\d{6,7})/ig)
		{
			my $new_postid = scalar(keys(%$postid_index)) - $postid_index->{$1};
			$the_post->{description} =~ s/$egloosinfo->{blogurl}\/(\d{6,7})/$egloosinfo->{newblogurl}\/$new_postid/ig;
		}
	}
	
	# content : 글 내용
	$xml_writer->startTag("content");
	$xml_writer->cdata($the_post->{description});
	$xml_writer->endTag("content");
	
	# attachment : 파일.
	# 워낙 양이 많아서 서브루틴을 새롭게 만듬.
	attachment_file($the_post, $xml_writer);
	
	
	# ----------------------------------------------------------------------------- #
	#	트랙백 태그 처리를 시작합니다.
	# ----------------------------------------------------------------------------- #
	# 	트랙백을 xml에 쓰기
	#	start_trackbacks가 -1이라는 얘기는 하나도 없다는 뜻이다.
	#	물론 이 코드를 만든 이후에 trackback_count로 트랙백 개수를 확인하였기에 그것을 사용해도 상관없음.
	#	하지만 그 코드는 삭제 가능성이 있기에 삭제 가능성이 없는 이 코드를 그대로 사용하기로 함.
	if(-1 != $the_post->{start_trackbacks})
	{
		write_trackbacks($the_post, $all_trackback, $xml_writer);
	}
	
	
	# ----------------------------------------------------------------------------- #
	#	댓글 태그 처리를 시작합니다.
	# ----------------------------------------------------------------------------- #
	#	댓글을 xml에 쓰기
	#	위에 트랙백과 비슷한 얘기.
	#	댓글의 개수를 Postclass안에서 구해서 저장하였기에 이렇게 하지 않아도 되지만, 삭제 가능성이 있어 그대로 둠.
	if(-1 != $the_post->{start_comments})
	{
		write_comments($the_post, $all_comment, $xml_writer);
	}
	
	
	# Post 태그 닫기
	$xml_writer->endTag("post");
}


# 트랙백 xml에 쓰는 함수.
sub write_trackbacks ($\@$)
{
#	html 형식, trackback 개수, xml writer
	my ($the_post, $all_trackback, $xml_writer) = @_;
#	start_trackbacks와 end_trackback는 $all_trackback안에 해당 포스트에 연결되어 있는 트랙백의 시작 index와 끝 index를 말함.
#	따라서 trackback_point에서는 그 처음 index를 초기화하여 처리한 후 하나씩 증가하여 end_point까지 도착하도록 함.
	my $trackback_point = $the_post->{start_trackbacks};
	my $end_point = $the_post->{end_trackbacks};
	my $trackback_class; # TrackbackClass 임시 변수
	
#	루프.
#	start_trackbacks부터 end_trackbacks까지 달린다.
	for ( ; $trackback_point <= $end_point ; $trackback_point++)
	{
		$trackback_class = $all_trackback->[$trackback_point];
		
#		xml에 태그 쓰기.
#		이 함수를 만들 때 정신이 없어서 각 태그가 무엇을 뜻하는지 주석을 달지 않았음.
#		하지만 TrackbackClass.pm에 모두 적었기에 그 파일의 주석 참고.
		$xml_writer->startTag("trackback");
		
		$xml_writer->startTag("url");
		$xml_writer->cdata($trackback_class->{url});
		$xml_writer->endTag("url");
		
		$xml_writer->startTag("site");
		$xml_writer->cdata($trackback_class->{site});
		$xml_writer->endTag("site");
		
		$xml_writer->startTag("title");
		$xml_writer->cdata($trackback_class->{title});
		$xml_writer->endTag("title");
		
		$xml_writer->startTag("excerpt");
		$xml_writer->cdata($trackback_class->{excerpt});
		$xml_writer->endTag("excerpt");
		
		$xml_writer->startTag("received");
		$xml_writer->cdata($trackback_class->{received});
		$xml_writer->endTag("received");

#		ip의 경우 모르기에 emptytag로 처리한다.
		$xml_writer->emptyTag("ip");
		
		$xml_writer->endTag("trackback");
	}
}


# comment를 xml에 적는다.
# 방식은 위의 write_trackbacks 함수와 비슷하나 답댓글이 존재하기에 태그를 닫을 때 신경써야 한다.
sub write_comments ($\@$)
{
#	html 형식, comment 개수, xml writer
	my ($the_post, $all_comment, $xml_writer) = @_;
	my $comment_class; # CommentClass 임시 변수.
#	방식은 위에 write_trackbacks와 동일하다.
#	대신 메뉴릿 때문에 읽는 순서를 바꿔야 할 필요가 있다.
#	최적화를 우선으로 하여 먼저 if문으로 확인 후 for문을 달린다.
	
	if(0 == $the_post->{is_menu_page})
	{
		# 보통글
		my $comment_point = $the_post->{start_comments};
		my $end_point = $the_post->{end_comments};
		
	#	루프.
	#	각 배열별로 살펴본 후 xml에 쓰기
		for ( ; $comment_point <= $end_point ; $comment_point++)
		{
			$comment_class = $all_comment->[$comment_point];
			
	#		xml에 comment를 작성한다.
			$xml_writer->startTag("comment");
			
	#		commenter 태그 작성.
			$xml_writer->startTag("commenter");
			
			$xml_writer->startTag("name");
			$xml_writer->characters($comment_class->{who});
			$xml_writer->endTag("name");
			
			$xml_writer->startTag("homepage");
			$xml_writer->characters($comment_class->{href});
			$xml_writer->endTag("homepage");
			
			$xml_writer->emptyTag("ip");
			
			$xml_writer->endTag("commenter");
			
	#		나머지 태그 작성
			$xml_writer->startTag("content");
			$xml_writer->cdata($comment_class->{description});
			$xml_writer->endTag("content");
			
			$xml_writer->emptyTag("password");
			
			$xml_writer->startTag("secret");
			$xml_writer->cdata($comment_class->{is_secret});
			$xml_writer->endTag("secret");
			
			$xml_writer->startTag("written");
			$xml_writer->cdata($comment_class->{time});
			$xml_writer->endTag("written");
			
			
	#		답댓글이면 자신의 것(답댓글) 태그 닫기.
			if(0 == $comment_class->{is_root})
			{
				$xml_writer->endTag("comment");
			}
			
	#		마지막이거나 다음 것이 root comment라면 root comment 태그 닫기
	#		Perl은 어떠할지 모르나 lazy evaluation이 적용되는 것이라면,
	#		앞의 문이 true라면 뒤의 것은 실행하지 않을 것이다.
	#		따라서 설령 뒤의 것이 boundary를 넘어서 살펴보는 버그를 일으키는 코드가 될 수 있을지라도
	#		그 때는 이미 앞의 것이 true가 되어 실행되지 않을 것이기에 문제가 없을 것이다.
	#		하지만 이는 안되는 듯싶어 ||이 아니라 elsif로 처리.
			if($comment_point == $end_point)
			{
				$xml_writer->endTag("comment");
			}
			elsif(1 == $all_comment->[$comment_point+1]->{is_root})
			{
				$xml_writer->endTag("comment");
			}
		}	# for 문 종료.
	}
	else
	{
		# 메뉴릿
		# 반대 방향으로 읽어야 한다.
		my $comment_point = $the_post->{end_comments};
		my $end_point = $the_post->{start_comments};
		
	#	루프.
	#	각 배열별로 살펴본 후 xml에 쓰기
		for ( ; $comment_point >= $end_point ; $comment_point--)
		{
			$comment_class = $all_comment->[$comment_point];
			
	#		xml에 comment를 작성한다.
			$xml_writer->startTag("comment");
			
	#		commenter 태그 작성.
			$xml_writer->startTag("commenter");
			
			$xml_writer->startTag("name");
			$xml_writer->characters($comment_class->{who});
			$xml_writer->endTag("name");
			
			$xml_writer->startTag("homepage");
			$xml_writer->characters($comment_class->{href});
			$xml_writer->endTag("homepage");
			
			$xml_writer->emptyTag("ip");
			
			$xml_writer->endTag("commenter");
			
	#		나머지 태그 작성
			$xml_writer->startTag("content");
			$xml_writer->cdata($comment_class->{description});
			$xml_writer->endTag("content");
			
			$xml_writer->emptyTag("password");
			
			$xml_writer->startTag("secret");
			$xml_writer->cdata($comment_class->{is_secret});
			$xml_writer->endTag("secret");
			
			$xml_writer->startTag("written");
			$xml_writer->cdata($comment_class->{time});
			$xml_writer->endTag("written");
			
			
	#		답댓글이면 자신의 것(답댓글) 태그 닫기.
			if(0 == $comment_class->{is_root})
			{
				$xml_writer->endTag("comment");
			}
			
	#		마지막이거나 다음 것이 root comment라면 root comment 태그 닫기
	#		Perl은 어떠할지 모르나 lazy evaluation이 적용되는 것이라면,
	#		앞의 문이 true라면 뒤의 것은 실행하지 않을 것이다.
	#		따라서 설령 뒤의 것이 boundary를 넘어서 살펴보는 버그를 일으키는 코드가 될 수 있을지라도
	#		그 때는 이미 앞의 것이 true가 되어 실행되지 않을 것이기에 문제가 없을 것이다.
	#		하지만 이는 안되는 듯싶어 ||이 아니라 elsif로 처리.
			if($comment_point == $end_point)
			{
				$xml_writer->endTag("comment");
			}
			elsif(1 == $all_comment->[$comment_point-1]->{is_root})
			{
				$xml_writer->endTag("comment");
			}
		}	# for 문 종료.
	}
}


# 포토로그 백업.
# 이 함수는 내 블로그 포토로그를 백업한 후 사용을 하지 않았고, 사람들이 버그 리포트를 하지 않아서 변화가 거의 없음.
sub BackupPhotolog ($)
{
	my ($eid) = @_;
	
	my_print("다음으로 포토로그 백업을 진행하겠습니다.\n");
	my_print("사진 양에 따라 시간이 오래 걸릴 수 있습니다.\n");
	my_print("사진은 photo 폴더에 id별로 생성이 되며, txt 파일에 앨범 정보를 기록합니다.\n");

	# 예제.
	#http://www.egloos.com/adm/photo/photolog_list.php?eid=c0049460&key=63662
	#$EgloosInfo::mech->get('http://www.egloos.com/adm/photo/photolog_list.php?eid=c0049460&key=63662');
	#my $content = $EgloosInfo::mech->content();
	my @albumid_arr;
	my $i;
	
	# 폴더 만들기.
	if(!(-e './photo/'))
	{
		mkdir('./photo/') or die "폴더 만들기 에러.\n";
	}
	
	my_print("앨범 ID를 가져오는 중...\n");
	# album id들을 가져오기.
	for($i = 1 ; ; $i++)
	{
	#	예제.
	#	http://www.egloos.com/adm/photo/album_info.php?eid=c0049460&pg=1
		my $albumlistURL = 'http://www.egloos.com/adm/photo/album_info.php?eid=' . $eid. '&pg=' . $i;
		my $content = getpage($albumlistURL, 0);
		
	#	다 봤으면 종료.
		if($content =~ m/<ul id="album_menu"><li class="white" style="cursor : default;">&nbsp;<\/li>/i)
		{
			last;
		}
	
	#	albumid 찾아서 저장
		my @albumid_fields = split /<li onclick="open_menu/, $content;
		shift @albumid_fields; # 처음 것 제거.
		my $start_needle = 'this,';
		my $end_needle = ',document.phfrm';
		
	#	postid들을 가져오기.
		my $temp;
		my $temp2;
		for $temp2 (@albumid_fields)
		{
			$temp = findstr($temp2, $start_needle, $end_needle);
			if(-1 != $temp)
			{
				push @albumid_arr, $temp;
			}
		}
	}
	my_print("앨범 ID를 가져오기 완료...\n\n");
	
	my_print("각 앨범에 접근하여 사진을 가져오는 중...\n");
	# album id로 사진 목록 가져오기.
	for my $albumid (@albumid_arr)
	{
#		파일이 존재하면 불러오고 없으면 새로 만들기. - 2009-01-13
#		여기서 album_info.txt를 잡은 이유는 이 파일이 마지막에 생성되며, 만들 때 적는 정보는 이미 다운로드 받은 것에서 적는 것이기에 네트워크를 이용하지 않아 에러 확률이 매우 낮다.(램에서 하드로 적는 것이니...)
		my $filename = './photo/' . $albumid . '/' . "album_info.txt";
		if(-e $filename)
		{
			# 파일이 있기에 다음 것을 본다.
			open (DESIN, "<:encoding(utf8)", $filename) or die $!;
			my $album_title = <DESIN>;
			chomp($album_title);
			close(DESIN);
			my_print($album_title . "은 이미 다운로드 받았습니다.\n");
			
			next; # else를 했으니 굳이 할 필요는 없으나...
		}
		else
		{
			# 파일이 없기에 다운로드 받는다.
			#	사진 이름 설정.
			$i = 1;
			
		#	albumid로 디렉토리 만들기.
			if(!(-e './photo/' . $albumid))
			{
				mkdir('./photo/' . $albumid) or die "폴더 만들기 에러.\n";
			}
		#	예제.
		#	http://www.egloos.com/adm/photo/photolog_list.php?eid=c0049460&key=63662
			my $picturelistURL = 'http://www.egloos.com/adm/photo/photolog_list.php?eid=' . $eid. '&key=' . $albumid;
			my $content = getpage($picturelistURL, 0);
			
		#	예제. - 앨범 제목.
		#	<div id=\"abm_subject\" class=\"subject\">20081101 동래역</div>
			$content =~ m/<div id=\\"abm_subject\\" class=\\"subject\\">(.*?)<\/div>/i;
			my $album_subject = $1;
			
		#	예제. - 앨범 설명.
		#	<div id=\"abm_content\" class=\"content\">20081101 동래역</div>
			$content =~ m/<div id=\\"abm_content\\" class=\\"content\\">(.*?)<\/div>/i;
			my $album_content = $1;
			
		#	예제. - 앨범 사진 장수와 만든 시간.
		#	<div class=\"info\">(16장) 2008-11-04 13:03</div>
			$content =~ m/<div class=\\"info\\">(.*?)<\/div>/i;
			my $album_info = $1;
			
			my_print("앨범 - " . $album_subject . "(을/를) 다운로드 하고 있습니다.\n");
			
		#	사진을 URL 분류.
			my @picture_fields = split /onclick=\\"imgview/, $content;
			shift @picture_fields; # 처음 것 제거.
			
		#	사진들을 가져오기. 즉, 다운로드 받기. 방법은 PostClass.pm에서 쓰이는 것과 동일하다.
		#	따라서 주석은 그 곳에 있는 것을 참고.
			my $temp2;
			for $temp2 (@picture_fields)
			{
				$temp2 =~ m/\('(http:\/\/[[:alnum:][:punct:]^>^<^"^']+\.(jpg|gif|png|jpeg))',/igc;
				my $img_url = $1; # 그림 url
				my $img_extension = $2; # 그림 파일 확장자
		#		이미지 저장할 경로 설정.
				my $istr = numtonumstr($i);
				my $img_dest = './photo/' . $albumid . '/' . $istr . '.' . $img_extension;
				if(-1 == downImage($img_url, $img_dest, 0))
				{
#					2009.1.22
					print_txt('포토로그 사진 다운로드 에러 : ' . $img_url . ' 앨범 : ' . $album_subject);
				}
				$i++;
			}
			
			open(OUT, ">:encoding(utf8) ", $filename) or die $!;
			print OUT
			'앨범 제목 : ' . $album_subject . "\n" .
			'앨범 설명 : ' . $album_content . "\n" .
			'사진 개수 및 앨범 만든 시간 : ' . $album_info . "\n";
			close(OUT);
		}
	} # end of for my $albumid (@albumid_arr)
	my_print("앨범 다운로드 완료...\n\n");
}


# 기존 이글루스 글 고치기.
# 이 함수는 나만 썼음.
# 이상하게도 기존에 내가 쓰던 RPC::XML은 editpost가 제대로 되지 않았음.
# 물론 예전에 성공하였기에 좀 더 살펴보면 사용이 가능하겠지만, WordPress::XMLRPC에서 잘 작동되기에 그것을 가져왔음.
# 다른 곳에도 이 함수를 쓰면 좋겠지만, 일단 여기서만 쓰는 것이라 바꾸지 않음.
# 일단 사용하지 않으니 주석 처리.
sub editpost ($$$$$)
{
#	my ($egloosinfo, $postid, $newblogid, $newblogurl, $new_description) = @_;
#	
#	my $o = WordPress::XMLRPC->new({
#	username => $egloosinfo->{id},
#	password => $egloosinfo->{apikey},
#	proxy => $egloosinfo->{apiurl},
#	});
#	
#	
#	# xmlrpc를 이용해서 글을 가져옴.
#	my $post = $o->getPost($postid);
#	
#	# 글에 맞게 수정.
#	my $new_link = $newblogurl . '/' . $newblogid;
#	
#	$new_description =~ s/POST_TITLE/$post->{title}/ig;
#	$new_description =~ s/POST_LINK/$new_link/ig;
#	
#	$post->{description} = $new_description;
#	
#	
#	# UTF8 인코딩 
#	utf8::encode($post->{title});
#	utf8::encode(@{$post->{categories}}[0]);
#	utf8::encode($post->{description});
#	
#	
#	# 글 바꾸기.
#	my_print("URL : " . $post->{link} . " 글을 바꿉니다.\n");
#	$o->editPost($postid, $post, 1);
}

# 모든 글, 트랙백, 댓글 가져와서 저장하기.
sub get_all_list ($)
{
	my ($egloosinfo) = @_;
	my $i; # 리스트 페이지 넘버.
	
	# dat가 저장될 디렉토리 만들기.
	if(!(-e './data/'))
	{
		mkdir('./data/') or die "폴더 만들기 에러.\n";
	}
	
	$i = 1;
	
	# 페이지 개수 가져오기.
	my $listURL = 'http://admin.egloos.com/contents/blog/trackback/page/' . $i . '?listcount=50';
	my $content = getpage($listURL, 0);
	my $pagenum = ($egloosinfo->{trackback_count} / 50) + 1;
	
#	trackback dat가 저장될 디렉토리 만들기.
	if(!(-e './data/trackbacks'))
	{
		mkdir('./data/trackbacks') or die "폴더 만들기 에러.\n";
	}
	
	# 트랙백들을 가져오기.
	for($i = 1 ; $i <= $pagenum ; $i++)
	{
#		파일이 존재하면 불러오고 없으면 새로 만들기. - 2009-01-13
		my $filename = 'data/trackbacks/' . numtonumstr($i) . '.dat';
		my $the_trackback; # 아마도 최적화가 되지 않을까?
		if(!(-e $filename))
		{
#			파일이 없기에 가져와서 저장하기.
			$listURL = 'http://admin.egloos.com/contents/blog/trackback/page/' . $i . '?listcount=50';
			$content = getpage($listURL, 0);
			
#			저장하기.
			open(OUT, ">:encoding(utf8) " , $filename) or die $!;
			print OUT $content;
			close(OUT);
		}
	}
	my_print("트랙백 리스트 다운로드 완료...\n");
	
	# 댓글 리스트 가져오기 
	$i = 1;
	
	# 페이지 개수 가져오기.
	$listURL = 'http://admin.egloos.com/contents/blog/comment/page/' . $i . '?listcount=50';
	$content = getpage($listURL, 0);
	$pagenum = ($egloosinfo->{comment_count} / 50) + 1;
	
#	comment dat가 저장될 디렉토리 만들기.
	if(!(-e './data/comments'))
	{
		mkdir('./data/comments') or die "폴더 만들기 에러.\n";
	}
	
	# 덧글들을 가져오기.
	for($i = 1 ; $i <= $pagenum ; $i++)
	{
#		파일이 존재하면 불러오고 없으면 새로 만들기. - 2009-01-13
		my $filename = 'data/comments/' . numtonumstr($i) . '.dat';
		my $the_comment;
		if(!(-e $filename))
		{
#			파일이 없기에 가져와서 저장하기.
			$listURL = 'http://admin.egloos.com/contents/blog/comment/page/' . $i . '?listcount=50';
			$content = getpage($listURL, 0); # 개행 없이 저장.
			
#			저장하기.
			open(OUT, ">:encoding(utf8) " , $filename) or die $!;
			print OUT $content;
			close(OUT);
		}
	}
	
	my_print("댓글 리스트 다운로드 완료...\n");
}



# 모든 글 가져와서 저장하기.
sub get_all_post ($\%)
{
	my ($egloosinfo, $postid_index) = @_;
	my @all_post;
	my $i; # 리스트 페이지 넘버.
	my $p_index = 0;
	
	#	trackback dat가 저장될 디렉토리 만들기.
	if(!(-e './data/posts'))
	{
		mkdir('./data/posts') or die "폴더 만들기 에러.\n";
	}
	
	# post들을 가져오기.
	for($i = 1 ; ; $i++)
	{
		my $content;
		
#		파일이 존재하면 불러오고 없으면 새로 만들기. - 2009-01-31
		my $filename = 'data/posts/' . numtonumstr($i) . '.dat';
		if(-e $filename)
		{
#			dat 파일이 존재하기에 불러오기.
#			파일 읽기. - editpost 함수에서 사용..
			$/ = undef;
			open (DESIN, "<:encoding(utf8)", $filename) or die $!;
			$content = <DESIN>;
			close(DESIN);
		}
		else
		{
#			파일이 없기에 가져와서 저장하기.
#			http://admin.egloos.com/contents/blog/post/page/1?date=&category=&listcount=50&kwd=
			# 이글루스 개편으로 인한 주소 수정 - NoSyu, 2012.08.07
			my $postlistURL = 'http://admin.egloos.com/contents/blog/post/page/' . $i . '?date=&category=&listcount=50&kwd=';
			$content = getpage($postlistURL, 0);
			
#			저장하기.
			open(OUT, ">:encoding(utf8) " , $filename) or die $!;
			print OUT $content;
			close(OUT);
		}
		
		#	리스트를 끝까지 다 봤으면 종료.
		if($content =~ m/해당 자료가 존재하지 않습니다./i)
		{
			last;
		}
		
#		postid 찾아서 저장
		my @post_fields = split /<tr><td><input type="checkbox" /, $content;
		shift @post_fields; # 처음 것 제거.
		
#		post 하나씩 가져오기.
		for my $post_field (@post_fields)
		{
			my %open_close; # 글의 공개여부.

#			글 공개여부.
			my $start_needle = "<i class=\"secret\">비밀글</i>";
			if($post_field =~ m/$start_needle/i)
			{
				$open_close{post} = 'private';
				$start_needle = "<td class=\"sub\"><i class=\"secret\">비밀글</i><a href=\"" . $egloosinfo->{blogurl} . '/';
			}
			else
			{
				$open_close{post} = 'public';
				$start_needle = "<td class=\"sub\"><a href=\"" . $egloosinfo->{blogurl} . '/';
			}

			my $postid = findstr($post_field, $start_needle, '"');
#			postid를 제대로 찾았다면 나머지 것도 얻는다.
			if(-1 != $postid)
			{
				# 덧글과 트랙백의 공개 여부는 이제 더 이상 여기에서 알 수 없다.

#				시간 정보 - 1시간 전이라는 식으로 나와있는 경우가 있기에....
#				댓글과 트랙백의 개수도 여기에 적습니다.
#				카테고리도 포함
#				예제
#				<td>2012-01-09</td><td title="미분류">미분류</td><td>8</td><td>0</td><td>0</td></tr>
				if($post_field =~ m/<td>(.+?)<\/td><td(?:[^>]+?)>(?:<i class="secret">비밀글<\/i>)?<a(?:[^>]+?)>(.+?)<\/a><\/td><td>(?:.+?)<\/td><td(?:[^>]+?)>(.+?)<\/td><td>([0-9]+?)<\/td><td>([0-9]+?)<\/td><td>(?:[0-9]+?)<\/td><\/tr>/ig)
				{
					$open_close{datetime_info} = $1;
					$open_close{post_title} = $2;
					$open_close{category_info} = $3;
					$open_close{comment_cnt} = $4;
					$open_close{trackback_cnt} = $5;
				}
				
#				파일이 존재하면 불러오고 없으면 새로 만들기. - 2009-01-11
#				여기서 말하는 파일은 post에 대한 정보가 담겨져있는 content.xml을 말함.
#				이 파일은 PostClass를 만든 후 즉, 안의 그림파일이나 첨부파일을 다 다운로드 받은 후 저장되기에 이 파일이 존재한다는 말은 제대로 다 받았다는 것을 의미한다.
				my $filename = 'data/' . $postid . '/content.xml';
				my $the_post; # 해당 포스트 클래스 임시 변수.
				my $content_all; # 만약 xml 파일이 존재한다면 이를 hash로 읽어들여 처리한다.
				if(-e $filename)
				{
#					xml 파일이 존재하기에 불러오기.
#					XMLin은 xml을 불러들여 tag별로 hash 형식으로 만든다.
#					좀 더 자세한 얘기는 cpan의 XML::Simple을 참조.
					$content_all = XMLin($filename);
					
#					post 변수 생성.
					$the_post = PostClass->new($postid, $egloosinfo, 1, $content_all , %open_close);
				}
				else
				{
#					파일이 존재하지 않기에 새롭게 만들기.
#					post 변수 생성.
					$the_post = PostClass->new($postid, $egloosinfo, 0, 0, %open_close);
					
#					xml 파일 쓰기.
					write_post_xml($filename, $the_post);
				}
				
#				배열에 글 정보 저장.
				push @all_post, $the_post;
				
#				배열 index 저장.
#				해당 이글루스 포스트 아이디를 key로 하여 그 value를 all_post의 index로 하였다.
#				이것으로 이글루스 포스트 아이디로 all post 몇 번째에 있는지 알 수 있다.
				$postid_index->{$the_post->{postid}} = $p_index;
				$p_index++; # 배열 인덱스 증가.
				
#				처리 완료 문구 출력.
#				사실 이 출력을 만들기 전에 하는 것이 디버깅하기에 편하나 만들어야 정보를 얻을 수 있고 그 정보를 출력할 수 있기에 앞뒤가 맞지 않게 된다. 따라서 완료 후에 해당 정보를 출력하게 할 수밖에 없다. 이 파라독스를 해결할 수 있는 방법이 있을까?
				my_print("URL : " . $egloosinfo->{blogurl} . "/" . $postid . " - 제목 : " . $the_post->{title} . "\n");
			} # end of  if(-1 != $postid)
			else
			{
#				2009-1-13 - 버그잡기용으로 추가.
#				하도 버그가 많이 나와서 if 문에 else문을 붙여 버그를 잡아보자는 생각에 형식상으로 하나 만들었다.
#				하지만 아직 여기에 대해 리포트가 된 적은 없다.
				my_print("get_all_post 함수에서 postid를 찾지 못했습니다.\n");
				my_print('error.txt를 nosyu@nosyu.pe.kr으로 보내주시길 바랍니다.' . "\n");
				print_txt("BackUpEgloos_Subs__get_all_post\n\n" . $egloosinfo->{blogurl} . "\n\n" . $post_field . "\n\n" . $content); # 디버그용.
				die;
			}
		} # end of  for my $post_field (@post_fields)
	} # end of  for($i = 1 ; ; $i++)
	
	return @all_post; # all_post 배열 반환.
}


# 모든 트랙백 가져오기
sub get_all_trackback ($\@\%)
{
	my ($egloosinfo, $all_post, $postid_index) = @_;
	my @all_trackback;
	my $i = 1;
	my $listURL;
	my $content;
	
	# 페이지 개수 가져오기.
	my $trackback_all_num = $egloosinfo->{trackback_count};
	my $pagenum = ($trackback_all_num / 50) + 1;
	
#	trackback dat가 저장될 디렉토리 만들기.
	if(!(-e './data/trackbacks'))
	{
		mkdir('./data/trackbacks') or die "폴더 만들기 에러.\n";
	}
	
#	프로그램 시작부터 24시간 안의 것은 새롭게 받는다.
	my $dt_today = DateTime->from_epoch( epoch => time(), time_zone => 'Asia/Seoul' );
	$dt_today->subtract(days => 1);
	my_print("지금부터 24시간 안에 올라온 트랙백을 받기 위해 해당 글에 접속합니다.\n");
	
	# 트랙백들을 가져오기.
	for($i = 1 ; $i <= $pagenum ; $i++)
	{
#		파일이 존재하면 불러오고 없으면 새로 만들기. - 2009-01-13
		my $filename = 'data/trackbacks/' . numtonumstr($i) . '.dat';
		my $the_trackback; # 아마도 최적화가 되지 않을까?
		if(-e $filename)
		{
#			dat 파일이 존재하기에 불러오기.
#			파일 읽기. - editpost 함수에서 사용..
			$/ = undef;
			open (DESIN, "<:encoding(utf8)", $filename) or die $!;
			$content = <DESIN>;
			close(DESIN);
		}
		else
		{
#			파일이 없기에 가져와서 저장하기.
			$listURL = 'http://admin.egloos.com/contents/blog/trackback/page/' . $i . '?listcount=50';
			$content = getpage($listURL, 0);
			
#			저장하기.
			open(OUT, ">:encoding(utf8) " , $filename) or die $!;
			print OUT $content;
			close(OUT);
		}
		
#		trackback 별로 찾아서 저장
		my @trackback_fields = split /<tr><td><input type="checkbox" /, $content;
		shift @trackback_fields; # 처음 것 제거.
		
#		trackback 하나씩 가져오기.
		for my $trackback_field (@trackback_fields)
		{
#			배열에 글 정보 저장.
			$the_trackback = TrackbackClass->new($egloosinfo, $egloosinfo->{blogurl}, $trackback_field, $egloosinfo->{newblogurl}, $dt_today, $postid_index, $all_post);
			push @all_trackback, $the_trackback;
			
			my_print("제목 : " . $the_trackback->{title} . "\n");
			
		} # end of  for my $trackback_field (@trackback_fields)
	} # end of  for($i = 1 ; $i <= $pagenum ; $i++)
	
#	정렬.
	@all_trackback = sort subsort @all_trackback;
	
#	각 Post들에게 위치 알려줌.
	my $all_trackback_size = $#all_trackback;
	my $j; # end postion, $i는 start position
	my $start_ele_postid;
	
	for($i = 0, $j = 1; $i <= $all_trackback_size ; )
	{
#		처음 것 설정.
		$start_ele_postid = $all_trackback[$i]->{postid};
		
#		다를 때까지 달린다.		
		while($j <= $all_trackback_size && $start_ele_postid == $all_trackback[$j]->{postid})
		{
			$j++;
		}
		
#		셋팅.
		my $post_arr_index = $postid_index->{$start_ele_postid};
		$all_post->[$post_arr_index]->{start_trackbacks} = $i;
		$all_post->[$post_arr_index]->{end_trackbacks} = $j-1;
		
		$i = $j;
		$j++;
	}
	
	return @all_trackback;
}


# 모든 덧글 가져오기
sub get_all_comment ($\@\%)
{
	my ($egloosinfo, $all_post, $postid_index) = @_;
	my @all_comment;
	my $i = 1;
	my $listURL;
	my $content;
	
	# 페이지 개수 가져오기.
	my $comment_all_num = $egloosinfo->{comment_count};
	my $pagenum = ($comment_all_num / 50) + 1;
	
#	comment dat가 저장될 디렉토리 만들기.
	if(!(-e './data/comments'))
	{
		mkdir('./data/comments') or die "폴더 만들기 에러.\n";
	}
	
#	프로그램 시작부터 24시간 안의 것은 새롭게 받는다.
	my $dt_today = DateTime->from_epoch( epoch => time(), time_zone => 'Asia/Seoul' );
	$dt_today->subtract(days => 1);
	my_print("지금부터 24시간 안에 올라온 댓글을 받기 위해 해당 글에 접속합니다.\n");
	
	# 덧글들을 가져오기.
	for($i = 1 ; $i <= $pagenum ; $i++)
	{
#		파일이 존재하면 불러오고 없으면 새로 만들기. - 2009-01-13
		my $filename = 'data/comments/' . numtonumstr($i) . '.dat';
		my $the_comment;
		if(-e $filename)
		{
#			dat 파일이 존재하기에 불러오기.
#			파일 읽기. - editpost 함수에서 사용..
			$/ = undef;
			open (DESIN, "<:encoding(utf8)", $filename) or die $!;
			$content = <DESIN>;
			close(DESIN);
		}
		else
		{
#			파일이 없기에 가져와서 저장하기.
			$listURL = 'http://admin.egloos.com/contents/blog/comment/page/' . $i . '?listcount=50';
			$content = getpage($listURL, 0); # 개행 없이 저장.
			
#			저장하기.
			open(OUT, ">:encoding(utf8) " , $filename) or die $!;
			print OUT $content;
			close(OUT);
		}
		
		
	#	comment 별로 찾아서 저장
		my @comment_fields = split /<tr><td><input type="checkbox" /m, $content;
		shift @comment_fields; # 처음 것 제거.
		
	#	post 하나씩 가져오기.
		for my $comment_field (@comment_fields)
		{
#			배열에 글 정보 저장.
			$the_comment = CommentClass->new($egloosinfo, $egloosinfo->{blogurl}, $comment_field, $dt_today, $postid_index, $all_post);
#			에러 발생으로 -1이 넘어오지 않으면 배열에 저장한다.
			if(-1 != $the_comment)
			{
				push @all_comment, $the_comment;
				
				my_print("URL : " . $egloosinfo->{blogurl} . '/' . $the_comment->{id} . " - 댓글쓴이 : " . $the_comment->{who} . "\n");
			}
		} # end of  for my $comment_field (@comment_fields)
	} # end of  for($i = 1 ; $i <= $pagenum ; $i++)
	
#	정렬.
	@all_comment = sort subsort @all_comment;
	
#	각 Post들에게 위치 알려줌.
	my $all_comment_size = $#all_comment;
	my $j; # end postion, $i는 start position
	my $start_ele_postid;
	
	for($i = 0, $j = 1; $i <= $all_comment_size ; )
	{
#		처음 것 설정.
		$start_ele_postid = $all_comment[$i]->{postid};
		
#		다를 때까지 달린다.
		while($j <= $all_comment_size && $start_ele_postid == $all_comment[$j]->{postid})
		{
			$j++;
		}
		
#		셋팅.
		my $post_arr_index = $postid_index->{$start_ele_postid};
		$all_post->[$post_arr_index]->{start_comments} = $i;
		$all_post->[$post_arr_index]->{end_comments} = $j-1;
		
		$i = $j;
		$j++;
	}
	return @all_comment;
}


# all_comment와 all_trackback 정렬하는 함수.
# http://www.wellho.net/forum/Perl-Programming/Sorting-a-list-of-hashes.html
sub subsort
{
	$$a{id} cmp $$b{id};
}

# 첨부파일 저장.
sub attachment_file ($$)
{
	my ($the_post, $xml_writer) = @_;
	my($f) = File::Util->new();
	
#	파일이 있을 때까지 달린다.
	while($the_post->{description} =~ m/\[##_1C\|(.*?)\|(.*?)\| _##\]/igc)
	{
		my $filename = $1;
		my $fileinfo = $2;
		$filename =~ m/\.(.{2,4})$/i;
		my $file_extension = $1; # 파일 확장자
		my $mime_type; # mime type
		my $width;
		my $height;
		my $file_content = $f->load_file('data/' . $the_post->{postid} . '/' . $filename);
		my $filesize = $f->size('data/' . $the_post->{postid} . '/' . $filename);
		
#		mime type, width, hieght 구하기.
		if('pdf' eq $file_extension or 'zip' eq $file_extension)
		{
			$mime_type = 'application/' . $file_extension;
			$width = 0;
			$height = 0;
		}
		else
		{
#			mime type 맞추기.
			if('jpg' eq $file_extension)
			{
				$mime_type = 'image/jpeg';
			}
			else
			{
				$mime_type = 'image/' . $file_extension;
			}
			
#			width, height 구하기.
#			예제.
#			[##_1C|1044461297.png|width="490" height="88.1072555205" alt=""| _##]
			$fileinfo =~ m/width="(.*?)" height="(.*?)"/i;
			$width = $1;
			$height = $2;
		} # end of mime type, width, hieght 구하기.
		
#		xml 쓰기.
		$xml_writer->startTag("attachment", "mime"=>$mime_type,
						"width"=>$width, "height"=>$height, "size"=>$filesize);
						
#		파일 이름.
		$xml_writer->startTag("name");
		$xml_writer->characters($filename);
		$xml_writer->endTag("name");
		
#		label도 그냥 파일 이름으로 하겠습니다.
#		기존의 파일 이름을 하려고 하였습니다만, 이 점 양해 부탁드립니다.
		$xml_writer->startTag("label");
		$xml_writer->characters($filename);
		$xml_writer->endTag("label");
		
#		enclosure는 무엇인지 모르겠습니다.
		$xml_writer->startTag("enclosure");
		$xml_writer->characters('0');
		$xml_writer->endTag("enclosure");
		
#		시간은 글의 발행시간과 동일.
		$xml_writer->startTag("attached");
		$xml_writer->characters($the_post->{time});
		$xml_writer->endTag("attached");
		
#		다운 받은 횟수를 어떻게 알 수 있겠습니까?!
		$xml_writer->startTag("downloads");
		$xml_writer->characters('0');
		$xml_writer->endTag("downloads");
		
#		content - 파일 내용.
		$xml_writer->startTag("content");
		$xml_writer->characters(encode_base64($file_content, ''));
		$xml_writer->endTag("content");

#		xml 태그 닫기.
		$xml_writer->endTag("attachment");
		
	} # end of  while($the_post->{description} =~ m/\[##_1C\|(.*?)\|(.*?)\|_##\]/ig)
}

# utf8 decode
sub my_print($)
{
	my ($src) = @_;
#	찍히는 것 백업.
	if($#print_text < 70)
	{
		push @print_text, $src;
	}
	else
	{
		shift @print_text;
		push @print_text, $src;
	}
	
#	OS에 따라 처리.
#	Linux이면 그대로 출력하고 Windows이면 cp949에 맞게 처리.
	if('linux' eq $^O)
	{
#		리눅스.
		utf8::decode($src);
		utf8::encode($src);
		print $src;
	}
	elsif('MSWin32' eq $^O)
	{
#		윈도우.
		utf8::decode($src);
		print encode("cp949", $src);
	}
	else
	{
#		하지만 위의 것은 32bit 머신이라 64는 어떨지 몰라 일단 나머지도 윈도우 방식으로 처리.
		utf8::decode($src);
		print encode("cp949", $src);
	}
}


# post를 xml에 적는 함수.
sub write_post_xml ($$)
{
	my ($filename, $the_post) = @_;
	
#	xml 파일 만들기.
	my $output = new IO::File(">" . $filename);
	my $xml_writer = new XML::Writer(OUTPUT => $output, ENCODING => 'utf-8', DATA_MDE => 1, DATA_INDENT => 4);
	$xml_writer->xmlDecl("UTF-8");
	
	$xml_writer->startTag("the_post");
	
#	내용 적기.
#	postid, description, time, title, link, category,
#	visibility, acceptComment, acceptTrackback,
#	file_count, start_trackbacks, end_trackbacks,
#	start_comments, end_comments, content_html

	$xml_writer->startTag("postid");
	$xml_writer->characters($the_post->{postid});
	$xml_writer->endTag("postid");
	
	$xml_writer->startTag("description");
	$xml_writer->cdata($the_post->{description});
	$xml_writer->endTag("description");
	
	$xml_writer->startTag("time");
	$xml_writer->characters($the_post->{time});
	$xml_writer->endTag("time");
	
	$xml_writer->startTag("title");
	$xml_writer->characters($the_post->{title});
	$xml_writer->endTag("title");
	
	$xml_writer->startTag("link");
	$xml_writer->characters($the_post->{link});
	$xml_writer->endTag("link");
	
	$xml_writer->startTag("category");
	$xml_writer->characters($the_post->{category});
	$xml_writer->endTag("category");
	
	$xml_writer->startTag("visibility");
	$xml_writer->characters($the_post->{visibility});
	$xml_writer->endTag("visibility");
	
	$xml_writer->startTag("acceptComment");
	$xml_writer->characters($the_post->{acceptComment});
	$xml_writer->endTag("acceptComment");
	
	$xml_writer->startTag("acceptTrackback");
	$xml_writer->characters($the_post->{acceptTrackback});
	$xml_writer->endTag("acceptTrackback");
	
	$xml_writer->startTag("file_count");
	$xml_writer->characters($the_post->{file_count});
	$xml_writer->endTag("file_count");
	
	$xml_writer->startTag("start_trackbacks");
	$xml_writer->characters($the_post->{start_trackbacks});
	$xml_writer->endTag("start_trackbacks");
	
	$xml_writer->startTag("end_trackbacks");
	$xml_writer->characters($the_post->{end_trackbacks});
	$xml_writer->endTag("end_trackbacks");
	
	$xml_writer->startTag("start_comments");
	$xml_writer->characters($the_post->{start_comments});
	$xml_writer->endTag("start_comments");
	
	$xml_writer->startTag("end_comments");
	$xml_writer->characters($the_post->{end_comments});
	$xml_writer->endTag("end_comments");
	
	$xml_writer->startTag("trackback_count");
	$xml_writer->characters($the_post->{trackback_count});
	$xml_writer->endTag("trackback_count");
	
	$xml_writer->startTag("comment_count");
	$xml_writer->characters($the_post->{comment_count});
	$xml_writer->endTag("comment_count");
	
	$xml_writer->startTag("is_menu_page");
	$xml_writer->characters($the_post->{is_menu_page});
	$xml_writer->endTag("is_menu_page");
	
	$xml_writer->startTag("content_html");
#	에러 발생 - 2009.1.12 - 이유는 유니코드 때문인 듯...
#	확인하니 그 문자는 xml에 담을 수 없다고 나옴. 그래서 지우라고 함.;;;
	$xml_writer->cdata($the_post->{content_html});
	$xml_writer->endTag("content_html");
	
	
	# XML 종료
	$xml_writer->endTag("the_post"); 
	$xml_writer->end();
	
	# 파일 쓰기
	$output->close();
	
}


# XML 파일 처음부터 끝까지 만들기.
# 원래 이 코드는 main.pl(Egloos2TTXML.pl)에 있었으나 코드가 너무 길어 여기로 옮김.
sub writeTTXML($$$$\@\@\@\%)
{
	# 이글루스 정보, 나머지.... 자세한 것은 위에서.. 쿨럭....
	my ($egloosinfo, $number, $how_many, $all_post_count, $all_post, $all_trackback, $all_comment, $postid_index) = @_;
	
	# XML 시작
	my_print("XML 파일 제작 시작...\n");
	# 숫자를 넣어 하나씩 증가.
	my $output = new IO::File(">egloos_$egloosinfo->{id}_" . numtonumstr($number) . ".xml");
	# DATA_MODE => 1 이면 xml 각 요소마다 정렬되어 작성이 된다.
	# 따라서 xml을 보기에도 편하다.
	my $xml_writer = new XML::Writer(OUTPUT => $output, ENCODING => 'utf-8', DATA_MODE => 1, DATA_INDENT => 4);
	
	# xml이 utf8으로 코딩된다는 것을 명시한다.
	$xml_writer->xmlDecl("UTF-8");
	# 예제 : <blog type="tattertools/1.1" migrational="true">
	# 이것은 프리덤의 자료를 보고 만들었기에 별 생각없이 따라했다.
	# migrational이 뜻하는 바를 몰랐지만...
	# 왜 Textcube는 TTXML에 대한 자세한 문서가 없는지 불만이다.
	# migrational을 true로 하여 계속 추가할 수 있도록 만든다.
	$xml_writer->startTag("blog", "type" => "tattertools/1.1", "migrational" => "true");
	
	# 예제
	#<setting>
	#<title>NoSyu's English Blog</title>
	#<name>NoSyu</name>
	#</setting>
	# start가 있다면 end가 있어야한다.
	# 문서를 보면 알지만 endTag는 굳이 이름을 넣을 필요가 없다.
	# 하지만 코드 읽기가 편하고자 일부러 넣었다.
	$xml_writer->startTag("setting");
	$xml_writer->startTag("title");
	$xml_writer->characters($egloosinfo->{blog_title});
	$xml_writer->endTag("title");
	$xml_writer->startTag("name");
	$xml_writer->characters($egloosinfo->{author});
	$xml_writer->endTag("name");
	$xml_writer->endTag("setting");
	
	# 카테고리
	# XML-RPC를 통해 카테고리들을 받아온다.
	# 이 코드는 예전에 이글루스 백업 프로그램을 만들 때 쓴 것을 그대로 가져왔다.
	# 정확하게는 파일을 나눈 틀은 그대로 가져왔고, 수정 및 추가를 하였으니...
	#my_print("XML-RPC API를 통해 카테고리를 가지고 오는 중...\n");
	
	# 예전에 작성한 것.
	# XML-RPC로 하니까 잘 안 된다고 하여 모바일에서 가져오게함.
	# 결국 XML-RPC는 쓰이지 않게 되었음. 
	#my $cli = RPC::XML::Client->new($egloosinfo->apiurl());
	#my $req = RPC::XML::request->new('metaWeblog.getCategories', '0', $egloosinfo->id(), $egloosinfo->apikey());
	#my $resp = $cli->send_request($req);
	#my $results = $resp->value();
	
#	# 가져온 카테고리 자료를 가지고 하나씩 xml 파일을 작성한다.
#	# $results 앞에 @을 붙인 이유는 해당 변수를 배열로 생각하라는 뜻이다.
#	my $priority_id = 1;
#	foreach (@$results)
#	{
#		# foreach 구문 안에서 $_은 괄호 안의 것이 하나씩 나타낸다.
#		# $_ 앞에 %을 붙인 이유는 위에 @$results의 경우와 비슷하다.
#		# 자세한 것은 Perl 책을 참고하자.
#		my %temp = %$_;
#	#	카테고리가 전체인 경우 제외한다.
#	#	이는 Textcube에도 전체는 따로 등록하는 것이 아니라 알아서 처리하기 때문이다.
#		if($temp{title} !~ m/전체/)
#		{
#	#		카테고리 태그 시작
#			$xml_writer->startTag("category");
#			
#	#		이름 태그 시작
#			$xml_writer->startTag("name");
#			$xml_writer->characters($temp{title});
#			$xml_writer->endTag("name");
#			
#	#		이글루스의 경우 카테고리 밑에 카테고리는 존재하지 않는다.
#	#		위의 설명은 틀렸다.
#	#		priority는 카테고리의 순서를 나타내는 것이다.
#			$xml_writer->startTag("priority");
#			$xml_writer->characters($priority_id);
#			$xml_writer->endTag("priority");
#			$xml_writer->endTag("category");
#			$priority_id++;
#		}
#	}

	# mobile page에 접근
	my_print("mobile page를 통해 카테고리를 가지고 오는 중...\n");
	my $result_page = getpage($egloosinfo->{blogurl} . '/m/category', 0);
	$result_page = findstr($result_page, '<ul class="prev_list">', '</ul>');
	
	my @results = split /<\/span>/, $result_page;
	
	my $priority_id = 1;
	foreach (@results)
	{
		my $target_category = findstr($_, '<li [^>]+?>', ' <span>');
		chomp($target_category);
		if($target_category =~ /-1/)
		{
			next;
		}
		
	#	카테고리가 전체인 경우 제외한다.
	#	이는 Textcube에도 전체는 따로 등록하는 것이 아니라 알아서 처리하기 때문이다.
	#	카테고리 태그 시작
		$xml_writer->startTag("category");
		
	#	이름 태그 시작
		$xml_writer->startTag("name");
		$xml_writer->characters($target_category);
		$xml_writer->endTag("name");
		
	#	priority는 카테고리의 순서를 나타내는 것이다.
		$xml_writer->startTag("priority");
		$xml_writer->characters($priority_id);
		$xml_writer->endTag("priority");
		$xml_writer->endTag("category");
		$priority_id++;
	}

	my_print("카테고리 가져오기 완료.\n\n");
	
	
	# 파일 읽기. - editpost 함수에서 사용..
	# 일단 이 기능은 공개하지 않았다.
	# 굳이 쓰고자 하는 사람이 없기 때문이다.
	#$/ = undef;
	#open (DESIN, "<:encoding(utf8)", "description") or die $!;
	#my $new_description = <DESIN>;
	#close(DESIN);
	
	# 저장되어 있는 post의 개수까지 Loop를 돈다.
	# 방향은 뒤집어서 진행한다.
	my_print("각 글에 하나씩 접근하여 xml에 적습니다.\n");
	if(0 == $number)
	{
		# xml 파일 하나로 처리.
		# 예전 코드 그대로 사용.
		my $ttxml_postid = 1;
		for my $the_post (@$all_post)
		{
			# 포스트 하나 xml에 쓰기.
			write_post($egloosinfo, $the_post, $xml_writer, $ttxml_postid, @$all_trackback, @$all_comment, %$postid_index);
		#	기존의 포스트 수정.
		#	현재 쓰지 않기에 주석으로 처리.
		#	editpost($egloosinfo, $postid, $i, $egloosinfo->{newblogurl}, $new_description);
			$ttxml_postid++;
		}
	}
	else
	{
		# xml 파일을 나눠야 하는 경우.
		my $idx = ($number - 1) * 100;
		my $end_idx = $number * 100;
		my $the_post; # 해당 포스트.
		for( ; $idx < $end_idx ; $idx++)
		{
			$the_post = @$all_post[$idx]; # 해당 포스트.
			
			# 포스트 하나 xml에 쓰기.
			write_post($egloosinfo, $the_post, $xml_writer, ($idx+1), @$all_trackback, @$all_comment, %$postid_index);
		#	기존의 포스트 수정.
		#	현재 쓰지 않기에 주석으로 처리.
		#	editpost($egloosinfo, $postid, $i, $egloosinfo->{newblogurl}, $new_description);
		}
	}
	my_print("모든 글과 댓글, 트랙백을 가져와서 xml에 작성하였습니다.\n\n");
	
	# 블로그 태그 닫기
	$xml_writer->endTag("blog");
	
	# XML 종료 
	$xml_writer->end();
	
	# 파일 핸들 닫기.
	$output->close();
}

__END__

# 모든 글 가져와서 저장하기.
sub m_get_all_post_trackback_comment ($)
{
	my ($egloosinfo) = @_;
	my @all_post;
	my $i; # 리스트 페이지 넘버.
	my $p_index = 0;
	
	# 디렉토리 만들기.
	if(!(-e './data/mobile'))
	{
		mkdir('./data/mobile') or die "폴더 만들기 에러.\n";
	}
	
	# post list들을 가져오기.
	for($i = 1 ; ; $i++)
	{
		my $content;
		
#		파일이 존재하면 불러오고 없으면 새로 만들기. - 2009-01-31
		my $filename = 'data/mobile/post_list/' . numtonumstr($i) . '.dat';
		if(-e $filename)
		{
#			dat 파일이 존재하기에 불러오기.
#			파일 읽기. - editpost 함수에서 사용..
			$/ = undef;
			open (DESIN, "<:encoding(utf8)", $filename) or die $!;
			$content = <DESIN>;
			close(DESIN);
		}
		else
		{
#			파일이 없기에 가져와서 저장하기.
			my $postlistURL = 'http://www.egloos.com/adm/post/chgpost_info.php?pagecount=50&eid=' . $egloosinfo->{eid}. '&pg=' . $i;
			$content = getpage($postlistURL, 0);
			
#			저장하기.
			open(OUT, ">:encoding(utf8) " , $filename) or die $!;
			print OUT $content;
			close(OUT);
		}
		
		#	리스트를 끝까지 다 봤으면 종료.
		if($content =~ m/해당 자료가 존재하지 않습니다./i)
		{
			last;
		}
		
#		postid 찾아서 저장
		my @post_fields = split /<tr bgcolor=/, $content;
		shift @post_fields; # 처음 것 제거.
		
#		post 하나씩 가져오기.
		for my $post_field (@post_fields)
		{
			my $start_needle = '<td width="360" class="black"><a href="' . $egloosinfo->{blogurl} . '/';
			my $postid = findstr($post_field, $start_needle, '"');
#			postid를 제대로 찾았다면 나머지 것도 얻는다.
			if(-1 != $postid)
			{
				my %open_close; # 글, 트랙백과 덧글의 공개여부. PostClass 안에서 처리할 수 있으나 관리 페이지에 나오는 것이 좀 더 깔끔하게 처리할 수 있어 이렇게 hash로 만든 후 인자로 전달.
				
#				글 공개여부.
				$start_needle = '<img src="http://md.egloos.com/img/eg/post_security1.gif"';
				if($post_field =~ m/$start_needle/i)
				{
					$open_close{post} = 'private';
				}
				else
				{
					$open_close{post} = 'public';
				}
#				덧글 공개여부
				$start_needle = '<td width="45" align="center" class="red">x</td>';
				if($post_field =~ m/$start_needle/i)
				{
					$open_close{comment} = 0;
				}
				else
				{
					$open_close{comment} = 1;
				}
#				트랙백 공개여부.
				$start_needle = '<td width="50" align="center" class="red">x</td>';
				if($post_field =~ m/$start_needle/i)
				{
					$open_close{trackback} = 0;
				}
				else
				{
					$open_close{trackback} = 1;
				}
#				시간 정보 - 1시간 전이라는 식으로 나와있는 경우가 있기에....
				$open_close{datetime_info} = findstr($post_field, '<td width="80" align="center" class="black">', '<\/td>');
#				댓글과 트랙백의 개수도 여기에 적습니다.
				$open_close{comment_cnt} = findstr($post_field, '<td width="45" align="center" class="black">', '<\/td>');
				$open_close{trackback_cnt} = findstr($post_field, '<td width="50" align="center" class="black">', '<\/td><\/tr>');
						
#				파일이 존재하면 불러오고 없으면 새로 만들기. - 2009-01-11
#				여기서 말하는 파일은 post에 대한 정보가 담겨져있는 content.xml을 말함.
#				이 파일은 PostClass를 만든 후 즉, 안의 그림파일이나 첨부파일을 다 다운로드 받은 후 저장되기에 이 파일이 존재한다는 말은 제대로 다 받았다는 것을 의미한다.
				my $filename = 'data/mobile/' . $postid . '/content.xml';
				my $the_post; # 해당 포스트 클래스 임시 변수.
				my $content_all; # 만약 xml 파일이 존재한다면 이를 hash로 읽어들여 처리한다.
				if(!(-e $filename))
				{
#					파일이 존재하지 않기에 새롭게 만들기.					
#					post 변수 생성.
					$the_post = PostClass_m->new($postid, $egloosinfo, 0, 0, %open_close );
					
					#	xml 파일 만들기.
					my $output = new IO::File(">" . $filename);
					my $xml_writer = new XML::Writer(OUTPUT => $output, ENCODING => 'utf-8', DATA_MDE => 1, DATA_INDENT => 4);
					$xml_writer->xmlDecl("UTF-8");
					
					write_post($egloosinfo, $the_post, $xml_writer, $ttxml_postid, @$all_trackback, @$all_comment, %$postid_index);
					
#					xml 파일 쓰기.
					#write_post_xml($filename, $the_post);
				}

#				배열에 글 정보 저장.
				push @all_post, $the_post;
				
#				배열 index 저장.
#				해당 이글루스 포스트 아이디를 key로 하여 그 value를 all_post의 index로 하였다.
#				이것으로 이글루스 포스트 아이디로 all post 몇 번째에 있는지 알 수 있다.
				#$postid_index->{$the_post->{postid}} = $p_index;
				#$p_index++; # 배열 인덱스 증가.
				
#				처리 완료 문구 출력.
#				사실 이 출력을 만들기 전에 하는 것이 디버깅하기에 편하나 만들어야 정보를 얻을 수 있고 그 정보를 출력할 수 있기에 앞뒤가 맞지 않게 된다. 따라서 완료 후에 해당 정보를 출력하게 할 수밖에 없다. 이 파라독스를 해결할 수 있는 방법이 있을까?
				my_print("URL : " . $egloosinfo->{blogurl} . "/" . $postid . " - 제목 : " . $the_post->{title} . "\n");
			} # end of  if(-1 != $postid)
			else
			{
#				2009-1-13 - 버그잡기용으로 추가.
#				하도 버그가 많이 나와서 if 문에 else문을 붙여 버그를 잡아보자는 생각에 형식상으로 하나 만들었다.
#				하지만 아직 여기에 대해 리포트가 된 적은 없다.
				my_print("get_all_post 함수에서 postid를 찾지 못했습니다.\n");
				my_print('error.txt를 nosyu@nosyu.pe.kr으로 보내주시길 바랍니다.' . "\n");
				print_txt("BackUpEgloos_Subs__get_all_post\n\n" . $egloosinfo->{blogurl} . "\n\n" . $post_field . "\n\n" . $content); # 디버그용.
				die;
			}
		} # end of  for my $post_field (@post_fields)
	} # end of  for($i = 1 ; ; $i++)
	
	return @all_post; # all_post 배열 반환.
}

# xml파일에 post 들을 적는 함수.
# main.pl에서 이 함수를 호출하여 post들을 xml 파일에 적는다.
sub m_write_post ($$$$\@\@\%)
{
#	이글루스 정보, 처리해야 할 post(PostClass form), xml을 적을 수 있는 핸들러, Textcube에서 쓰일 post id, trackback 들, comment들, post 배열을 추적할 수 있는 hash table  
	my ($egloosinfo, $the_post, $xml_writer,
		$id, $all_trackback, $all_comment, $postid_index) = @_;
	
	# ----------------------------------------------------------------------------- #
	#	xml에 Post 태그를 시작합니다.
	# ----------------------------------------------------------------------------- #
	# Post 태그 시작하기
	$xml_writer->startTag("post", "slogan" => $the_post->{title});
	
	# ----------------------------------------------------------------------------- #
	#	Post 제목과 내용 등을 처리합니다.
	#	댓글과 트랙백은 밑에서 처리합니다.
	# ----------------------------------------------------------------------------- #
	# title : 제목
	$xml_writer->startTag("title");
	$xml_writer->characters($the_post->{title});
	$xml_writer->endTag("title");
	
	# id : 글의 번호
	$xml_writer->startTag("id");
	$xml_writer->characters($id);
	$xml_writer->endTag("id");
	
	# visibility : 공개여부
	$xml_writer->startTag("visibility");
	$xml_writer->characters($the_post->{visibility});
	$xml_writer->endTag("visibility");
	
	# location : 지역 태그 - 이글루스에는 이런 태그가 없음.
	$xml_writer->startTag("location");
	$xml_writer->characters('/');
	$xml_writer->endTag("location");
	
	# password : 비밀번호 라고 해석되나 정확하게 무엇인지 모름. 역시 이글루스에는 없음.\
	# 그렇다고 아무거나 넣으면 쉽게 뚫릴 듯싶어 그것은 좋지 않다고 판단.
	# 그래서 그냥 현재 시각을 인자로 하여 md5 함수를 돌린 값을 넣었음.
	# 그러하여도 삭제나 수정은 잘 되는 것을 확인.
	$xml_writer->startTag("password");
	$xml_writer->characters(md5_base64(time));
	$xml_writer->endTag("password");
	
	# acceptComment : 댓글을 적을 수 있는지인지... 여튼 비슷한 것인 듯싶다.
	$xml_writer->startTag("acceptComment");
	$xml_writer->characters($the_post->{acceptComment});
	$xml_writer->endTag("acceptComment");
	
	# acceptTrackback : 트랙백을 적을 수 있는지인지... 여튼 비슷한 것인 듯싶다.
	$xml_writer->startTag("acceptTrackback");
	$xml_writer->characters($the_post->{acceptTrackback});
	$xml_writer->endTag("acceptTrackback");
	
	# published : 글을 발행한 날짜.
	# 이글루스의 경우 이 차이를 두지 않기에 created와 modified도 동일하게 한다.
	$xml_writer->startTag("published");
	$xml_writer->characters($the_post->{time});
	$xml_writer->endTag("published");
	
	$xml_writer->startTag("created");
	$xml_writer->characters($the_post->{time});
	$xml_writer->endTag("created");
	
	$xml_writer->startTag("modified");
	$xml_writer->characters($the_post->{time});
	$xml_writer->endTag("modified");
	
	# category : 카테고리
	$xml_writer->startTag("category");
	$xml_writer->characters($the_post->{category});
	$xml_writer->endTag("category");
	
	# tag : 태그 - 있는 만큼 태그로 만든다.
	# <ul class="tag"><li><a href="/m/tag/%ED%83%9C%EA%B7%B8">태그</a></li><li><a href="/m/tag/%ED%83%9C%EA%B7%B81">태그1</a></li><li class="last"><a href="/m/tag/%ED%83%9C%EA%B7%B82">태그2</a></li></ul>
	my @tags; # 태그.
	# 본문 부분 가져오기
	my $page = $the_post->{content_html};
	my $tag_html = findstr($page, '<ul class="tag">', '<\/ul>');
	if($page =~ m/<ul class="tag">(.+?)<\/div>/g)
	{
		my $tag_html = $1;
		# 예제 : 주민등록번호,&nbsp;도용,&nbsp;탈퇴,&nbsp;웹사이트,&nbsp;사이트
		$tag_html =~ s/<li><a href="[^"]+">(.*?)<\/a><\/li>/$1<>/ig;
		@tags = split /<>/, $tag_html;
		
		# tags 변수 안에 있는 것을 xml에 하나씩 쓰기.
		foreach (@tags)
		{
			$xml_writer->startTag("tag");
			$xml_writer->characters($_);
			$xml_writer->endTag("tag");
		}
	}
	
#	본문 안의 자신의 블로그 주소를 새로운 것으로 바꿈.
	#if(!('' eq $egloosinfo->{newblogurl}))
	#{
	#	if($the_post->{description} =~ m/$egloosinfo->{blogurl}\/(\d{6,7})/ig)
	#	{
	#		my $new_postid = scalar(keys(%$postid_index)) - $postid_index->{$1};
	#		$the_post->{description} =~ s/$egloosinfo->{blogurl}\/(\d{6,7})/$egloosinfo->{newblogurl}\/$new_postid/ig;
	#	}
	#}
	
	# content : 글 내용
	$xml_writer->startTag("content");
	$xml_writer->cdata($the_post->{description});
	$xml_writer->endTag("content");
	
	# attachment : 파일.
	# 워낙 양이 많아서 서브루틴을 새롭게 만듬.
	attachment_file($the_post, $xml_writer);
	
	
	# ----------------------------------------------------------------------------- #
	#	트랙백 태그 처리를 시작합니다.
	# ----------------------------------------------------------------------------- #
	# 	트랙백을 xml에 쓰기
	#	start_trackbacks가 -1이라는 얘기는 하나도 없다는 뜻이다.
	#	물론 이 코드를 만든 이후에 trackback_count로 트랙백 개수를 확인하였기에 그것을 사용해도 상관없음.
	#	하지만 그 코드는 삭제 가능성이 있기에 삭제 가능성이 없는 이 코드를 그대로 사용하기로 함.
	if(-1 != $the_post->{start_trackbacks})
	{
		m_write_trackbacks($the_post, $all_trackback, $xml_writer);
	}
	
	
	# ----------------------------------------------------------------------------- #
	#	댓글 태그 처리를 시작합니다.
	# ----------------------------------------------------------------------------- #
	#	댓글을 xml에 쓰기
	#	위에 트랙백과 비슷한 얘기.
	#	댓글의 개수를 Postclass안에서 구해서 저장하였기에 이렇게 하지 않아도 되지만, 삭제 가능성이 있어 그대로 둠.
	if(-1 != $the_post->{start_comments})
	{
		m_write_comments($the_post, $all_comment, $xml_writer);
	}
	
	
	# Post 태그 닫기
	$xml_writer->endTag("post");
}


# 트랙백 xml에 쓰는 함수.
sub m_write_trackbacks ($\@$)
{
#	html 형식, trackback 개수, xml writer
	my ($the_post, $all_trackback, $xml_writer) = @_;
	
	#		트랙백과 댓글 파일도 다운로드 받는다.
	my $idx;
	my $content_html_temp;
	my $trackback_count_div_10 = ceil($the_post->{trackback_count} / 10);
	my $filename_temp;
	for($idx = 1 ; $idx <= $trackback_count_div_10 ; $idx++)
	{
		# 트랙백 받기
		$filename_temp = 'data/mobile/' . $postid . '/trackback_list_' . $idx . '.xml';
		# 파일이 존재하지 않는다면 쓰기
		if(-e $filename_temp)
		{
			open(READ_HANDLE,"+< " . $filename_temp ) or die $!;
			$content_html_temp = <READ_HANDLE>;
			close(READ_HANDLE);
		}
		else
		{
			$content_html_temp = BackUpEgloos_Subs::getpage($egloosinfo->{blogurl} . '/m/trackback/' . $postid . '/page/' . $idx, 0);
			open(OUT, ">:encoding(utf8) " ,$filename_temp) or die $!;
			print OUT $content_html_temp;
			close(OUT);
		}
		
#		트랙백 별 쪼개기.
		my @trackback_fields = split /<div class="trackback_list">/, $content_html_temp;
		shift @trackback_fields; # 처음 것 제거.
		
#		트랙백 하나씩 처리하기.
		for my @trackback_field (@trackback_fields)
		{
			my $target_url = findstr(@trackback_field, '<em><a href="', '"');
			
			# xml에 태그 쓰기.
			# 이 함수를 만들 때 정신이 없어서 각 태그가 무엇을 뜻하는지 주석을 달지 않았음.
			# 하지만 TrackbackClass.pm에 모두 적었기에 그 파일의 주석 참고.
			$xml_writer->startTag("trackback");
			
			$xml_writer->startTag("url");
			$xml_writer->cdata($target_url);
			$xml_writer->endTag("url");
			
			$xml_writer->startTag("site");
			$xml_writer->cdata($target_url);	# mobile에서는 알 수 없음.
			$xml_writer->endTag("site");
			
			$xml_writer->startTag("title");
			$xml_writer->cdata($trackback_class->{title});
			$xml_writer->endTag("title");
			
			$xml_writer->startTag("excerpt");
			$xml_writer->cdata($trackback_class->{excerpt});
			$xml_writer->endTag("excerpt");
			
			$xml_writer->startTag("received");
			$xml_writer->cdata($trackback_class->{received});
			$xml_writer->endTag("received");
	
			# ip의 경우 모르기에 emptytag로 처리한다.
			$xml_writer->emptyTag("ip");
			
			$xml_writer->endTag("trackback");
		}
	}
	
	
#	start_trackbacks와 end_trackback는 $all_trackback안에 해당 포스트에 연결되어 있는 트랙백의 시작 index와 끝 index를 말함.
#	따라서 trackback_point에서는 그 처음 index를 초기화하여 처리한 후 하나씩 증가하여 end_point까지 도착하도록 함.
	my $trackback_point = $the_post->{start_trackbacks};
	my $end_point = $the_post->{end_trackbacks};
	my $trackback_class; # TrackbackClass 임시 변수
	
#	루프.
#	start_trackbacks부터 end_trackbacks까지 달린다.
	for ( ; $trackback_point <= $end_point ; $trackback_point++)
	{
		$trackback_class = $all_trackback->[$trackback_point];
		
#		xml에 태그 쓰기.
#		이 함수를 만들 때 정신이 없어서 각 태그가 무엇을 뜻하는지 주석을 달지 않았음.
#		하지만 TrackbackClass.pm에 모두 적었기에 그 파일의 주석 참고.
		$xml_writer->startTag("trackback");
		
		$xml_writer->startTag("url");
		$xml_writer->cdata($trackback_class->{url});
		$xml_writer->endTag("url");
		
		$xml_writer->startTag("site");
		$xml_writer->cdata($trackback_class->{site});
		$xml_writer->endTag("site");
		
		$xml_writer->startTag("title");
		$xml_writer->cdata($trackback_class->{title});
		$xml_writer->endTag("title");
		
		$xml_writer->startTag("excerpt");
		$xml_writer->cdata($trackback_class->{excerpt});
		$xml_writer->endTag("excerpt");
		
		$xml_writer->startTag("received");
		$xml_writer->cdata($trackback_class->{received});
		$xml_writer->endTag("received");

#		ip의 경우 모르기에 emptytag로 처리한다.
		$xml_writer->emptyTag("ip");
		
		$xml_writer->endTag("trackback");
	}
}


# comment를 xml에 적는다.
# 방식은 위의 write_trackbacks 함수와 비슷하나 답댓글이 존재하기에 태그를 닫을 때 신경써야 한다.
sub m_write_comments ($\@$)
{
#	html 형식, comment 개수, xml writer
	my ($the_post, $all_comment, $xml_writer) = @_;
	my $comment_class; # CommentClass 임시 변수.
#	방식은 위에 write_trackbacks와 동일하다.
	my $comment_point = $the_post->{start_comments};
	my $end_point = $the_post->{end_comments};
	
#	루프.
#	각 배열별로 살펴본 후 xml에 쓰기
	for ( ; $comment_point <= $end_point ; $comment_point++)
	{
		$comment_class = $all_comment->[$comment_point];
		
#		xml에 comment를 작성한다.
		$xml_writer->startTag("comment");
		
#		commenter 태그 작성.
		$xml_writer->startTag("commenter");
		
		$xml_writer->startTag("name");
		$xml_writer->characters($comment_class->{who});
		$xml_writer->endTag("name");
		
		$xml_writer->startTag("homepage");
		$xml_writer->characters($comment_class->{href});
		$xml_writer->endTag("homepage");
		
		$xml_writer->emptyTag("ip");
		
		$xml_writer->endTag("commenter");
		
#		나머지 태그 작성
		$xml_writer->startTag("content");
		$xml_writer->cdata($comment_class->{description});
		$xml_writer->endTag("content");
		
		$xml_writer->emptyTag("password");
		
		$xml_writer->startTag("secret");
		$xml_writer->cdata($comment_class->{is_secret});
		$xml_writer->endTag("secret");
		
		$xml_writer->startTag("written");
		$xml_writer->cdata($comment_class->{time});
		$xml_writer->endTag("written");
		
		
#		답댓글이면 자신의 것(답댓글) 태그 닫기.
		if(0 == $comment_class->{is_root})
		{
			$xml_writer->endTag("comment");
		}
		
#		마지막이거나 다음 것이 root comment라면 root comment 태그 닫기
#		Perl은 어떠할지 모르나 lazy evaluation이 적용되는 것이라면,
#		앞의 문이 true라면 뒤의 것은 실행하지 않을 것이다.
#		따라서 설령 뒤의 것이 boundary를 넘어서 살펴보는 버그를 일으키는 코드가 될 수 있을지라도
#		그 때는 이미 앞의 것이 true가 되어 실행되지 않을 것이기에 문제가 없을 것이다.
#		하지만 이는 안되는 듯싶어 ||이 아니라 elsif로 처리.
		if($comment_point == $end_point)
		{
			$xml_writer->endTag("comment");
		}
		elsif(1 == $all_comment->[$comment_point+1]->{is_root})
		{
			$xml_writer->endTag("comment");
		}
	}	# for 문 종료.
}



