# 2009-1-20
# 상세한 주석은 2009-1-23 부산으로 내려가는 버스 안에서 작성.
# 원래는 영화를 보려고 하였으나 코덱이 없다고 하여 주석이나 달고 있음.ㅜ

#!/usr/bin/perl

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
my_print("\t\t\tEgloos2TTXML ver 0.0.7.3\n");
my_print("\t\t\t\t\t\t- NoSyu's TOYBOX with Perl\n\n");
my_print("이 프로그램은 ver 0.0.7.2까지 문제점이던 카테고리 문제를 해결합니다.\n");
my_print("만들어지는 xml 파일은 카테고리만 백업합니다.\n\n");

my_print("===============================================================================\n");
my_print("=================================부탁드립니다!=================================\n");
my_print("이 프로그램으로 백업이나 이사하셨으면 제 블로그에 트랙백으로 결과를 알려주세요.\n");
my_print("나름 보람을 느끼고 싶은 NoSyu의 부탁입니다.\n");
my_print("=================================부탁드립니다!=================================\n");
my_print("===============================================================================\n\n");

#이글루스 정보 가져오기
my $egloosinfo; # 이 프로그램은 다중 계정을 지원하지 않기에 하나만 생성한다.
# 실행 시 들어온 인자가 두 개 혹은 세 개인 경우 그것을 아이디, 비밀번호, 새로운 블로그 주소로 인식한다.
# 새로운 블로그 주소는 옵션이다.
# 처음에는 이렇게 만들었으나 배포 시 사람들이 CUI에 익숙하지 않아서 인자 없이 실행시 STDIN으로 자료를 받기로 함.
if(1 == $#ARGV)
{
	# 들어온 인자가 두 개이기에 아이디와 비밀번호만 전달.
	my_print("로그인을 통해 이글루스 정보를 가져오는 중...\n");
	# 그리고 새로운 블로그 주소는 ''으로 처리한다. 이로서 EgloosInfo에서는 입력이 들어오지 않았다는 것을 알 수 있다.
	$egloosinfo = EgloosInfo->new($ARGV[0], $ARGV[1], '');
	
}
elsif(2 == $#ARGV)
{
	# 들어온 인자가 세 개임.
	my_print("로그인을 통해 이글루스 정보를 가져오는 중...\n");
	# 차례대로 넣는다.
	$egloosinfo = EgloosInfo->new($ARGV[0], $ARGV[1], $ARGV[2]);
}
# 기존에는 그냥 die 시켰으나 사용자들을 위해 입력을 받도록 추가 - 2009.1.15
else
{
	# 이글루스 아이디, 패스워드, 새로운 블로그 주소를 받을 변수를 미리 설정.
	# 왜냐하면 chomp로 개행문자(\n)을 없애기 위해서이다.
	my $id;
	my $pw;
	my $newblogurl;
	
	# 아이디를 받는다.
	my_print("로그인을 위해 이글루스 아이디와 비밀번호, \n그리고 이사를 위해 새로운 블로그 주소를 넣어주세요.\n");
	my_print("이글루스 아이디 :  ");
	chomp($id = <STDIN>);
	my_print("아이디 : $id\n");
	
	# 비밀번호를 받는다.
	my_print("\n이글루스 비밀번호(입력받은 비밀번호는 화면에 나오지 않습니다.) :  ");
	ReadMode 2; # password를 비밀로 받기 위해서 설정.
	chomp($pw = <STDIN>);
	ReadMode 0; # 원래 상태로 복구.
	# 비밀번호를 화면에 뿌리지 않는 이유는 print_txt에서 화면에 나온 메시지를 출력하기에 만약 화면에 뿌릴 경우 txt 파일로 비밀번호가 나오게 된다.
	my_print("\n비밀번호는 공개하지 않겠습니다.\n");
	
	# 새로운 블로그 주소를 받는다.
	$newblogurl = '';
	
	# Egloosinfo 변수를 생성한다.
	$egloosinfo = EgloosInfo->new($id, $pw, $newblogurl);
}
my_print("로그인 및 이글루스 정보 가져오기 완료.\n\n");

	# XML 시작
	my_print("XML 파일 제작 시작...\n");
	# 숫자를 넣어 하나씩 증가.
	my $output = new IO::File(">egloos_$egloosinfo->{id}_category.xml");
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
	my_print("XML-RPC API를 통해 카테고리를 가지고 오는 중...\n");
	my $cli = RPC::XML::Client->new($egloosinfo->apiurl());
	my $req = RPC::XML::request->new('metaWeblog.getCategories', '0', $egloosinfo->id(), $egloosinfo->apikey());
	my $resp = $cli->send_request($req);
	my $results = $resp->value();
	
	# 가져온 카테고리 자료를 가지고 하나씩 xml 파일을 작성한다.
	# $results 앞에 @을 붙인 이유는 해당 변수를 배열로 생각하라는 뜻이다.
	my $priority_id = 1;
	foreach (@$results)
	{
		# foreach 구문 안에서 $_은 괄호 안의 것이 하나씩 나타낸다.
		# $_ 앞에 %을 붙인 이유는 위에 @$results의 경우와 비슷하다.
		# 자세한 것은 Perl 책을 참고하자.
		my %temp = %$_;
	#	카테고리가 전체인 경우 제외한다.
	#	이는 Textcube에도 전체는 따로 등록하는 것이 아니라 알아서 처리하기 때문이다.
		if($temp{title} !~ m/전체/)
		{
	#		카테고리 태그 시작
			$xml_writer->startTag("category");
			
	#		이름 태그 시작
			$xml_writer->startTag("name");
			$xml_writer->characters($temp{title});
			$xml_writer->endTag("name");
			
	#		이글루스의 경우 카테고리 밑에 카테고리는 존재하지 않는다.
	#		위의 설명은 틀렸다.
	#		priority는 카테고리의 순서를 나타내는 것이다.
			$xml_writer->startTag("priority");
			$xml_writer->characters($priority_id);
			$xml_writer->endTag("priority");
			$xml_writer->endTag("category");
			
			my_print("카테고리 : " . $priority_id . " - " . $temp{title} . "\n");
			
			$priority_id++;
		}
	}
	my_print("카테고리 가져오기 완료.\n\n");
	
	# 블로그 태그 닫기
	$xml_writer->endTag("blog");
	
	# XML 종료 
	$xml_writer->end();
	
	# 파일 핸들 닫기.
	$output->close();

# 프로그램이 끝났음을 알린다.
# 하지만 프로그램을 윈도우에서 바로 시작한 사람은 이 메시지를 못 본다.
# 물론 이 밑에 STDIN으로 볼 수 있게 할 수 있으나 굳이 해야하는가 의문이다.
my_print("끝났습니다~^^\n\n");

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

