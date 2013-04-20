#!/usr/bin/perl

# 2009-1-20
# 상세한 주석은 2009-1-23 부산으로 내려가는 버스 안에서 작성.
# 원래는 영화를 보려고 하였으나 코덱이 없다고 하여 주석이나 달고 있음.ㅜ

use strict;
use warnings;
use Carp;
use BackUpEgloos_Subs; # 이 프로젝트에 쓰이는 서브루틴들이 있음.
use EgloosInfo; # 이글루스 정보를 가지고 있음. 로그인 후 쿠키를 가진 mech 변수도 있음.
use utf8; # 이글루스 정보들은 encoding으로 utf8으로 되어있기에 사용.
use Term::ReadKey; # 이글루스 비밀번호를 받을 때 화면상에 뿌리지 않도록 하고자 가져온 라이브러리.

# 에러 핸들러 등록 처리.
# die 명령으로 프로그램이 종료하려고 하면 print_txt 함수 호출.
# 여기에는 화면에 뿌리는 메시지도 저장하고 있기에 디버깅 및 오류 리포트에 좋음.
BEGIN {
	$SIG{__DIE__} = sub { print_txt($_[0]); };
}

#메시지 출력
my_print("\t\t\tEgloos2TTXML ver 0.0.11.2\n");
my_print("\t\t\t\t\t\t- NoSyu's TOYBOX with Perl\n\n");
my_print("이글루스를 백업하거나 Textcube, 티스토리로 이사할 수 있는 xml파일을 만듭니다.\n");
my_print("로그인을 하기에 비밀글과 비밀댓글도 가져오며, 그림파일을 백업합니다.\n\n");

my_print("그림과 글 정보는 data 폴더에 Post ID별로 생성됩니다.\n");
my_print("또한, posts, trackbacks, comments라는 폴더 안에 리스트들이 저장되어 있습니다.\n");
my_print("따라서 새롭게 시작할 때 이글루스에 접근하지 않고서 매우 빠른 속도로 진행합니다.\n");
my_print("새로운 글, 트랙백, 댓글을 받기 위해서는 세 폴더를 지우고 새롭게 실행하세요.\n\n");

#my_print("고급 사용법은 Egloos2TTXML.exe 아이디 비밀번호 새로운블로그URL 입니다.\n");
#my_print("새로운 블로그 주소는 옵션입니다. 즉, 넣고 싶지 않으시면 넣지 마세요.\n");
#my_print("새로운 블로그 주소는 끝에 반드시 /을 빼주세요.\n");
#my_print('예 : Egloos2TTXML_PAR.exe NoSyu ^^ http://nosyu.pe.kr' . "\n");
#my_print('혹은 Egloos2TTXML_PAR.exe만을 실행시켜도 됩니다.' . "\n\n");

#my_print("아직 테스트 중이기에 속도가 느리고, 안되는 것이 있을겁니다.\n");
my_print('문의사항은 http://nosyu.pe.kr이나 nosyu@nosyu.pe.kr로 연락주시기 바랍니다.' . "\n");
my_print("error로 시작하는 txt 파일을 보내주신다면 정확한 답변을 얻을 수 있습니다.\n\n");

my_print("===============================================================================\n");
my_print("=================================부탁드립니다!=================================\n");
my_print("이 프로그램으로 백업이나 이사하셨으면 제 블로그에 트랙백으로 결과를 알려주세요.\n");
my_print("나름 보람을 느끼고 싶은 NoSyu의 부탁입니다.\n");
my_print("=================================부탁드립니다!=================================\n");
my_print("===============================================================================\n\n");

#	OS에 따라 처리.
#	Linux이면 그대로 출력하고 Windows이면 cp949에 맞게 처리.
if('linux' eq $^O)
{
#	리눅스.
	my $script_exe = 'firefox ';
	system($script_exe . "nosyu.pe.kr/tag/Egloos2TTXML &");
}
elsif('MSWin32' eq $^O)
{
#	윈도우.
	my $script_exe = '@start "" /b "C:\Program Files\Internet Explorer\iexplore.exe" ';
	system($script_exe . "nosyu.pe.kr/tag/Egloos2TTXML");
}

#이글루스 정보 가져오기
my $egloosinfo; # 이 프로그램은 다중 계정을 지원하지 않기에 하나만 생성한다.
my $is_use_mobile;
# 그림 파일의 위치 묻기 
while(1)
{
	my_print("그림 파일은 어느 곳에서 가져올까요?\n");
	my_print("0. 모바일 페이지(추천)\n1. 메인 페이지\n> ");
	$is_use_mobile = <STDIN>;
	chomp($is_use_mobile);
	
	if('0' eq $is_use_mobile || '1' eq $is_use_mobile)
	{
		last;
	}
	else
	{
		my_print("0 혹은 1를 입력해주세요.\n\n");
	}
}
# 실행 시 들어온 인자가 두 개 혹은 세 개인 경우 그것을 아이디, 비밀번호, 새로운 블로그 주소로 인식한다.
# 새로운 블로그 주소는 옵션이다.
# 처음에는 이렇게 만들었으나 배포 시 사람들이 CUI에 익숙하지 않아서 인자 없이 실행시 STDIN으로 자료를 받기로 함.
if(1 == $#ARGV)
{
	# 들어온 인자가 두 개이기에 아이디와 비밀번호만 전달.
	my_print("로그인을 통해 이글루스 정보를 가져오는 중...\n");
	# 그리고 새로운 블로그 주소는 ''으로 처리한다. 이로서 EgloosInfo에서는 입력이 들어오지 않았다는 것을 알 수 있다.
	$egloosinfo = EgloosInfo->new($ARGV[0], $ARGV[1], '', $is_use_mobile, 0);
	
}
elsif(2 == $#ARGV)
{
	# 들어온 인자가 세 개임.
	my_print("로그인을 통해 이글루스 정보를 가져오는 중...\n");
	# 차례대로 넣는다.
	$egloosinfo = EgloosInfo->new($ARGV[0], $ARGV[1], $ARGV[2], $is_use_mobile, 0);
}
# 기존에는 그냥 die 시켰으나 사용자들을 위해 입력을 받도록 추가 - 2009.1.15
else
{
	# 이글루스 아이디, 패스워드, 새로운 블로그 주소를 받을 변수를 미리 설정.
	# 왜냐하면 chomp로 개행문자(\n)을 없애기 위해서이다.
	my $id;
	my $pw;
	my $newblogurl;
	my $is_nate;
	
	# 이글루스인지 네이트인지 확인한다.
	my_print("\n이글루스 로그인? 네이트 로그인?\n");
	my_print("이글루스 - 0, 네이트 - 1\n기본으로 이글루스로 설정됩니다.\n> ");
	chomp($is_nate = <STDIN>);
	if('' eq $is_nate || 1 != $is_nate)
	{
		my_print("이글루스 아이디와 비밀번호를 입력해주세요.\n");
	}
	else
	{
		my_print("네이트 아이디와 비밀번호를 입력해주세요.\n");
	}
	
	# 아이디를 받는다.
	my_print("\n로그인을 위해 아이디와 비밀번호, \n그리고 이사를 위해 새로운 블로그 주소를 넣어주세요.\n");
	my_print("아이디 :  ");
	chomp($id = <STDIN>);
	my_print("입력받은 아이디 : $id\n");
	
	# 비밀번호를 받는다.
	my_print("\n비밀번호(입력받은 비밀번호는 화면에 나오지 않습니다.) :  ");
	ReadMode 2; # password를 비밀로 받기 위해서 설정.
	chomp($pw = <STDIN>);
	ReadMode 0; # 원래 상태로 복구.
	# 비밀번호를 화면에 뿌리지 않는 이유는 print_txt에서 화면에 나온 메시지를 출력하기에 만약 화면에 뿌릴 경우 txt 파일로 비밀번호가 나오게 된다.
	my_print("\n비밀번호는 공개하지 않겠습니다.\n");
	
	# 새로운 블로그 주소를 받는다.
	my_print("\n새로운 블로그 주소\n필요없을 시 엔터만 치세요.\n적을 시 끝에 /을 제외하고 적어주세요.\n예 : http://nosyu.pe.kr\n새로운 블로그 주소 :  ");
	chomp($newblogurl = <STDIN>);
	# 재미있게도 아무런 입력이 없을 경우 ''과 같다.
	# 덕분에 굳이 바꿀 필요가 없다.
	if('' eq $newblogurl)
	{
		my_print("주소 변환을 하지 않겠습니다.\n\n");
	}
	else
	{
		my_print("본문, 트랙백, 덧글 안의 기존 블로그 주소가 " . $newblogurl . "(으로/로) 바뀝니다.\n\n");
	}
		
	# Egloosinfo 변수를 생성한다.
	$egloosinfo = EgloosInfo->new($id, $pw, $newblogurl, $is_use_mobile, $is_nate);
}
my_print("로그인 및 이글루스 정보 가져오기 완료.\n\n");

# 변수들.
my @all_post; # 모든 포스트, 이글루스 관리 글 목록의 글들을 차례대로 가져온다.
my @all_trackback; # 모든 트랙백, 이글루스 관리 트랙백 목록의 글들을 차례대로 가져온다.
my @all_comment; # 모든 코멘트, 이글루스 관리 댓글 목록의 글들을 차례대로 가져온다.
my %postid_index; # all_post에서 index 찾기 즉, 이글루스 postid를 입력으로 받으면 해당 글이 all_post 몇 번째 요소로 있는지 알 수 있게 hash table로 만들었다. 이는 postid가 나름 정렬이 되어있지만, 그렇지 않은 곳도 있기 때문이다.
my $number;
# 이제 어떤 작업을 할 것인지 선택받는다.
# 사용자의 입력을 받아야 하기에 무한루프로 처리한다.
# 그리고 일이 끝나면 last 명령어로 빠져나온다.
while(1)
{
	my_print("어떤 작업을 하시겠습니까?\n");
	#my_print("1. 이글루스 글, 트랙백, 댓글 다운로드\n2. 자료 불러온 후 TTXML 파일 만들기.\n3. 포토로그 사진 백업.\n> ");
	my_print("1. 이글루스 글, 트랙백, 댓글 다운로드\n2. 자료 불러온 후 TTXML 파일 만들기.\n> ");
	$number = <STDIN>;
	chomp($number);
	if('1' eq $number)
	{
		# 다운로드
		# 1번은 이글루스 백업에 주력한다.
		my_print("리스트 가져오는 중...\n");
		get_all_list($egloosinfo);
		my_print("글 가져오는 중...\n");
		@all_post = get_all_post($egloosinfo, %postid_index);
		my_print("글 다 가져왔습니다...\n\n");
		my_print("트랙백 가져오는 중...\n");
		@all_trackback = get_all_trackback($egloosinfo, @all_post, %postid_index);
		my_print("트랙백 다 가져왔습니다...\n\n");
		my_print("댓글 가져오는 중...\n");
		@all_comment = get_all_comment($egloosinfo, @all_post, %postid_index);
		my_print("댓글 다 가져왔습니다...\n\n");

		my_print("작업이 끝났습니다.\n\n");
		
		# 사용자의 입력을 받기 위해 만든 무한루프 빠져나가기. <- 처음 while(1)을 빠져나감.
		last;
	}
	elsif('2' eq $number)
	{
		my $numbers; # 유저로부터 받는 숫자.
		my $how_many;
		while(1)
		{
			my_print("\nXML 파일을 하나로 하겠습니까? 여러 개로 하겠습니까?\n");
			my_print("1. 하나로 만들기\n2. 여러 개로 만들기\n> ");
			$numbers = <STDIN>;
			chomp($numbers);
			
			
			if('1' eq $numbers)
			{
				last;
			}
			elsif('2' eq $numbers)
			{
				my_print("\n하나의 XML파일에 몇 개의 글을 담으시겠습니까?\n");
				my_print("1 이상의 숫자를 입력해주세요.\n글의 총 개수보다 작아야 합니다.\n> ");
				$how_many = <STDIN>;
				chomp($how_many);
				
				last;
			}
			else
			{
				my_print("1 혹은 2를 입력해주세요.\n\n");
			}
		}
		
		# 2번을 하기 위해 불러온다.
		my_print("리스트 가져오는 중...\n");
		get_all_list($egloosinfo);
		my_print("글 가져오는 중...\n");
		@all_post = get_all_post($egloosinfo, %postid_index);
		my_print("글 다 가져왔습니다...\n\n");
		my_print("트랙백 가져오는 중...\n");
		@all_trackback = get_all_trackback($egloosinfo, @all_post, %postid_index);
		my_print("트랙백 다 가져왔습니다...\n\n");
		my_print("댓글 가져오는 중...\n");
		@all_comment = get_all_comment($egloosinfo, @all_post, %postid_index);
		my_print("댓글 다 가져왔습니다...\n\n");
		
		my $all_post_count = scalar(@all_post); # all_post의 요소 개수.
		
		#	정렬.
		@all_post = sort { $a->{postid} cmp $b->{postid} } @all_post;
		
		# xml 파일을 나눌 것인지 아니면 하나로 할 것인지 사용자의 입력을 받는다.
		if('1' eq $numbers)
		{
			# 하나로 만들기에 나누지 않고 다 보낸다.
			# number는 0으로 한다. 물론 나눌 경우 1부터 시작하게 한다.
			my_print("파일 하나에 모든 자료를 적겠습니다.\n\n");
			writeTTXML($egloosinfo, 0, 0, $all_post_count, @all_post, @all_trackback, @all_comment, %postid_index);
			
			# 사용자의 입력을 받기 위해 만든 무한루프 빠져나가기.
			last;
		}
		elsif('2' eq $numbers)
		{
			# 여러 개로 나눠서 적는다.
			my $i = 0; # $how_many개씩의 배열 조각.
			
			while(($i * $how_many) <= $all_post_count)
			{
				$i++; # number를 증가시킨다.
				# xml 파일을 적는다.
				writeTTXML($egloosinfo, $i, $how_many, $all_post_count, @all_post, @all_trackback, @all_comment, %postid_index);
			}
			
			# 사용자의 입력을 받기 위해 만든 무한루프 빠져나가기.
			last;
		}
		
		# 사용자의 입력을 받기 위해 만든 무한루프 빠져나가기. <- 처음 while(1)을 빠져나감.
		last;
	}
#	elsif('3' eq $number)
#	{
#		# 포토로그 백업.
#		BackupPhotolog($egloosinfo->{eid});
#		
#		# 사용자의 입력을 받기 위해 만든 무한루프 빠져나가기.
#		last;
#	}
#	elsif('4' eq $number)
#	{
#		# 모바일 페이지로 작업한다.
#		my_print("XMLRPC 문제와 스킨의 다양성에 따라 작동하지 않는 경우가 있습니다.\n");
#		my_print("따라서 어느 이글루든 표준적으로 나오는 모바일 페이지를 이용하였습니다.\n");
#		my_print("모바일로 보는 것을 가져오는 것이기에 문제가 조금 있을 수 있지만,\n");
#		my_print("궁여지책 중 하나라는 점을 말씀드립니다.\n");
#		my_print("작업 폴더는 mobile 입니다.\n");
#		my_print("다시 시작하고 싶으시다면 이를 지우시길 바랍니다.\n");
#		
#		# 글을 하나씩 가져와서 폴더에 저장시킨다.
#		
#		
#		# 글을 하나씩 이어서 쓰는 방식으로 하여 XML 파일을 만든다.
#		
#		# 사용자의 입력을 받기 위해 만든 무한루프 빠져나가기.
#		last;
#	}
	else
	{
		# 1번과 2번이 아닌 다른 입력이 들어왔기에 얘기한다.
		#my_print("1, 2, 3, 4 중 하나를 입력해주세요.\n\n");
		my_print("1, 2 중 하나를 입력해주세요.\n\n");
	}
}

# 프로그램이 끝났음을 알린다.
# 하지만 프로그램을 윈도우에서 바로 시작한 사람은 이 메시지를 못 본다.
# 물론 이 밑에 STDIN으로 볼 수 있게 할 수 있으나 굳이 해야하는가 의문이다.
my_print("끝났습니다~^^\n\n");
my_print("프로그램 만든이 : NoSyu(http://nosyu.pe.kr)\n\n");

# 마지막 장면(?)을 볼 수 있게 <STDIN>을 붙인다.
my_print("엔터 혹은 Ctrl+C를 누르면 프로그램이 끝납니다.\n");
<STDIN>

# 도움이 된 사이트(페이지)
# 따로 만드는 것이 좋을 듯싶으나 어차피 문서화가 어려울 듯싶어 그냥 코드에 다 붙였다. 
#http://www.perlmonks.org/?node_id=644637
#http://search.cpan.org/~petdance/WWW-Mechanize/
#http://mwultong.blogspot.com/2006/07/perltk.html
#http://www.word.pe.kr/bbs/zboard.php?id=xml
#http://dev.tattersite.com/browser/projects/wp2tt/ttxml.xsd
#http://www.xml.com/pub/a/2001/04/18/perlxmlqstart1.html
#http://www.xmlrpc.com/metaWeblogApi
#http://search.cpan.org/~drolsky/DateTime-0.4501/lib/DateTime.pm
#http://search.cpan.org/~delta/Digest-Perl-MD5-1.6/lib/Digest/Perl/MD5.pm
#http://perldoc.perl.org/Digest/MD5.html
#http://search.cpan.org/~cpb/Flickr-Upload/Upload.pm
#http://www.perlmonks.org/?node_id=475869
#http://www.nntp.perl.org/group/perl.beginners/2007/07/msg93550.html

# Perl 코드 종료를 알림.
__END__

