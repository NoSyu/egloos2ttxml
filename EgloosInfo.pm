# 2009-1-13

package EgloosInfo;

use warnings;
use strict;
use Carp;
use WWW::Mechanize; # 웹페이지에 접근하는 아주 훌륭한 라이브러리.
use utf8; # 이글루스 정보들은 encoding으로 utf8으로 되어있기에 사용.
use LWP::Protocol::https;	# 로그인할 때 https를 쓴다. 따라서 이것이 설치되어 있어야 한다.

$EgloosInfo::mech = WWW::Mechanize->new(autocheck => 0);	# mesh 인자, autocheck를 0으로 설정하여 이 기능을 껐음. 따라서 에러가 발생해도 die로 죽지 않고, warning으로 내가 처리할 수 있게 되었다.
#$EgloosInfo::is_use_mobile = 0;
# 밑에 변수 옆에 얻는 함수를 적은 이유는 예전 코드의 영향이다.
# 사실 지우는 것이 조금 더 깔끔하고 좋겠지만, 일단 개인적인 이유로 남겨두었다.
# 리팩토링으로 삭제하여도 문제 없다.
# 물론 다른 코드에서는 저 함수를 사용하지 않는다.
my $apikey; # 이글루스 APIKEY. 얻는 함수 : getApiInfo()
my $apiurl; # 이글루스 APIURL. 얻는 함수 : getApiInfo()
my $blogurl; # 블로그 주소. 얻는 함수 ; getBlogInfo()
my $eid; # 숨겨진 아이디. 얻는 함수 ; getBlogInfo()
my $post_num; # 포스트 개수 얻는 함수 ; getBlogInfo()
my $blog_title; # 블로그 제목.
my $author; # 블로거 이름.
#my @postid_arr; # postid들의 배열. 처음에는 postid 배열을 가지고 백업하였으나 이제는 그렇게 하지 않기에 주석으로 처리하였음.
my $post_count; # 가지고 있는 포스트의 개수
#my $img_host_url; # 이미지를 옮길 URL. 처음에는 플릭커나 피카사에 그림을 올려 개인 계정에서도 무리 없이 사용하려고 하였으나 상당히 복잡했음.
# 피카사의 경우 외부에서 사진을 직접 접근하는 것은 허락되지 않는 듯싶었고, 플릭커의 경우 업로드 라이브러리가 있었으나 조금 복잡했음. 물론 오픈소스라 코드를 수정해서 만들 수 있었음. 하지만 결정적으로 외국 서버라 너무 느림.
# 따라서 그냥 xml 파일에 attachment로 파일을 붙이기로 함. 
my $trackback_count;
my $comment_count;

#생성자
sub new ($$$)
{
#	클래스 이름 전달
	my $class = shift;
#	아이디와 비밀번호, 새로운 블로그를 받음.
	my ($id, $pw, $newblogurl, $is_use_mobile) = @_;
	
#	로그인하기
	BackUpEgloos_Subs::my_print("로그인 중...\n");
	BackUpEgloos_Subs::login_egloos($id, $pw);
#	로그인이 제대로 되었는지 확인하기
#	블로그 정보 가져오기
	BackUpEgloos_Subs::my_print("로그인 완료...\n");
	# 암호 변수 제거
	$pw = 0;
	BackUpEgloos_Subs::my_print("블로그 정보 가져오는 중...\n");
	getBlogInfo();
#	블로그 API 주소 가져오기
	BackUpEgloos_Subs::my_print("블로그 API 주소 가져오는 중...\n");
	getApiInfo();
##	블로그 Post ID 주소 가져오기.
#	여기가 postid 배열을 만든 곳이나 이제 사용하지 않기에 주석으로 처리.
#	BackUpEgloos_Subs::my_print("블로그 Post ID 주소 가져오는 중...\n");
#	getPostids();
#	BackUpEgloos_Subs::my_print("작업할 글 개수는 총 " . $post_count . "개 입니다.\n");
	
#	이미지 저장할 폴더 만들기. - 있을 경우 만들지 않는다.
	if(!(-e 'data'))
	{
		mkdir('data') or die "폴더 만들기 에러.\n";
	}
	
#	변수 등록. 자세한 것은 생략.
	my $self = { apikey=>$apikey, apiurl=>$apiurl,
		blogurl=>$blogurl, eid=>$eid, post_num=>$post_num,
		id=>$id, blog_title=>$blog_title, author=>$author, newblogurl=>$newblogurl,
		post_count=>$post_count, trackback_count=>$trackback_count, comment_count=>$comment_count,
		is_use_mobile=>$is_use_mobile};
#	referencing
	bless ($self, $class);
	
#	종료
	return $self;
}

#getset 함수들
sub id { $_[0]->{id}=$_[1] if defined $_[1]; $_[0]->{id}; }
sub blogurl { $blogurl }
sub eid { $eid }
sub post_num { $post_num }
sub apiurl { $apiurl }
sub apikey { $apikey }
#sub postid_arr {return @postid_arr;}

#블로그 정보 가져오기
sub getBlogInfo
{
#	블로그 관리 페이지로 접근
	my $egloosurl = 'http://www.egloos.com';
	
#	needle 즉, 찾을 문자열의 앞뒤를 설정
#	예제 : <a class="myegloo"  href="http://dongdm.egloos.com/" title="내 이글루 가기" onclick="statClick('egsm1','RLA16');">내이글루</a>
	my $needle1 = '<a class="myegloo"  href="'; # 이글루 주소
#	예제 : <a href="http://www.egloos.com/egloo/insert.php?eid=f0012026">New Post</a>
	#my $needle2 = '<a href="http://www.egloos.com/adm/chgadm_main.php\?eid='; # 첫 페이지에서 숨겨진 아이디를 찾는 needle - ?가 들어가면 제대로 못 찾는다.
	my $needle2 = "'eglooid' : '"; # 이글루스가 개편하였기에 새롭게 찾아낸다. - NoSyu, 2012.08.07
	
	my $needle3 = '<div class="post">(?:.*?)<h3>post</h3>(?:.*?)<span>총 포스트 : '; # 포스트 개수를 찾는 needle
	my $needle_trackback_count = '<div class="post">(?:.*?)<h3>post</h3>(?:.*?)<span>총 트랙백 : '; # 트랙백 개수를 찾는 needle
	my $needle_comment_count = '<div class="post">(?:.*?)<h3>post</h3>(?:.*?)<span>총 덧글 : '; # 코멘트 개수를 찾는 needle
	
#	이글루스 메인 페이지를 가져온다.
	my $result = BackUpEgloos_Subs::getpage($egloosurl, 0);

	# 블로그 주소를 가져온다.
	$blogurl = BackUpEgloos_Subs::findstr($result, $needle1, '/?" title="내 이글루 가기"');
	
#	블로그 제목 가져오기.
#	예제.
#	<title>블로그 이사준비중...</title>
	$result = BackUpEgloos_Subs::getpage($blogurl, 0);
	$result =~ m/<title>(.*?)<\/title>/i;
	$blog_title = $1;
	
#	블로거 이름 가져오기.
#	예제.
#	<meta name="author" content="NoSyu" />
	$result =~ m/<meta name="author" content="(.*?)" \/>/i;
	$author = $1;
	
# 블로그의 eid를 가져온다.
	$eid = BackUpEgloos_Subs::findstr($result, $needle2, "'");
		
	my $adminURL = 'http://admin.egloos.com/';
	
	$result = BackUpEgloos_Subs::getpage($adminURL, 0);
	
	# 포스트 개수를 가져온다.
	# 내 기억으로 포스트 개수는 코드에서 쓰지 않는 것이다.
	# 처음에는 포스트 개수에 맞춰 페이지에도 접근하는 등의 여러 일을 하려고 하였으나 단순히 목록을 살펴보는 것으로 처리함.
	# 이유는 NoSyu.egloos.com의 경우 글 번호가 0과 -1이 있어 이글루 관리에 나오는 포스트 개수와 실제 개수가 다르다.
	# 하지만 일단 코드를 남겨두었다. 리팩토링으로 불필요하다고 판단되면 주석처리한다.
	$post_num = BackUpEgloos_Subs::findstr($result, $needle3, '</span>');
	$trackback_count = BackUpEgloos_Subs::findstr($result, $needle_trackback_count, '</span>');
	$comment_count = BackUpEgloos_Subs::findstr($result, $needle_comment_count, '</span>');
	
	#	1,000개 이상이면 콤마가 붙기에 이를 제거
	$post_num =~ s/,//g;
}


#API key값을 가져오는 함수
sub getApiInfo
{
	my $needle1 = '<th>URL</th>(?:.*?)<td>'; # APIURL을 찾는 needle
	my $needle2 = '<th>API Key</th>(?:.*?)<td>'; # APIKey를 찾는 needle
	
	my $pageURL = 'http://admin.egloos.com/blog/basic/popup/apikey';
	
	my $result = BackUpEgloos_Subs::getpage($pageURL, 0);
	#공백을 모두 제거한다.
	#$_ = $result;
	#s/\s//g; # 여기서 띄어쓰기까지 전부 제거되기에 위에 needle이 조금 이상함.
	#s/[\n\r\t]//g;
	
	# 블로그의 APIURL을 가져온다.
	$apiurl = BackUpEgloos_Subs::findstr($result, $needle1, '</td>');
	
	# 블로그의 APIKey을 가져온다.
	# APIKey 재발급이라는 것이 나타나고 조금 변화가 되어 제대로 작동하지 않았음 - 20090128
	$apikey = BackUpEgloos_Subs::findstr($result, $needle2, ' <span class="btns">');
}

# 이제 작업하지 않기에 주석 처리.
## post id들을 가져오기.
#sub getPostids
#{
#	my $i;
#	
#	# post id들을 가져오기.
#	for($i = 1 ; $i<2; $i++)
#	{
#		my $postlistURL = 'http://www.egloos.com/adm/post/chgpost_info.php?pagecount=50&eid=' . $eid. '&pg=' . $i;
#		my $content = getpage($postlistURL);
#		
#	#	다 봤으면 종료.
#		if($content =~ m/해당 자료가 존재하지 않습니다./i)
#		{
#			last;
#		}
#	
#	#	postid 찾아서 저장
#		my @postid_fields = split /<tr bgcolor=/, $content;
#		my $start_needle = '<td width="360" class="black"><a href="' . $blogurl . '/';
#		my $end_needle = '"';
#		
#	#	postid들을 가져오기.
#		my $temp;
#		my $temp2;
#		for $temp2 (@postid_fields)
#		{
#			$temp = findstr($temp2, $start_needle, $end_needle);
#			if(-1 != $temp)
#			{
#				push @postid_arr, $temp;
#				$post_count++;
#			}
#		}
#	}
#}

# Textcube ID는 1부터 1씩 증가하지만, Egloos ID는 그 방법을 잘 모르겠다.
# 아마도 날짜와 시간을 인자로 받아 그에 비례하여 점점 증가하는 값을 내놓는 함수를 쓰는 듯싶다.
# 여하튼 그 패턴을 쉽게 파악하기 어렵기에 이 둘을 맞추는 함수가 필요하지 않을까 생각하였다.
# 결론적으로 $postid_index hash table로 해결하였다.
# 따라서 이 함수는 필요가 없어져서 주석처리를 하였다.
# (정확하게 돌아가는지도 의문이지만...)
#sub getTextcubePostid_from_EgloosPostid ($)
#{
#	my $class = shift;
#	my $egloos_postid = shift;
#	
#	my $i = 1;
#	my $postid;
#	# 저장되어 있는 postid의 개수까지 Loop를 돈다.
#	# 방향은 뒤집어서 진행한다.
#	for $postid (reverse(@postid_arr))
#	{
#		# 찾기.
#		if($egloos_postid eq $postid)
#		{
#			last;
#		}
#		else
#		{
#			$i++;
#		}
#	}
#	
##	Textcube Post ID를 반환.
#	return $i;
#}

1;