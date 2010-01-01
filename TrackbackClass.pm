package TrackbackClass;

use warnings;
use strict;
use Carp;
use DateTime; # 트랙백이 쓰여진 시간이 Unix 시간으로 TTXML에 기록되기에 이를 사용한다.
use utf8; # 이글루스 정보들은 encoding으로 utf8으로 되어있기에 사용.

my $href; # 트랙백을 날린 글의 주소 - TTXML: url
my $post_title; # 트랙백 받은 글의 제목  - TTXML : title
my $blog_title; # 트래백 보낸 사람의 블로그 제목 - TTXML : site
my $description; # 본문 - TTXML : excerpt
my $time; # 시간 - TTXML : received
my $postid; # 트랙백이 걸린 post id
my $trackbackid; # trackback id
# IP는 나오지 않기에 처리하지 못함.

#생성자
sub new ($$$$$\%\@)
{
	my $class = shift;
#	이글루스 정보, 현 블로그 주소, 이글루 관리 트래백 목록에서 해당 트랙백 정보가 담긴 곳, 새로운 블로그 주소, 오늘, all_post index 찾기 hash table, post 배열.
	my ($egloosinfo, $blogurl, $trackback_field, $newblogurl, $dt_today,  $postid_index, $all_post) = @_;

#	postid와 trackbackid를 가져오기.	
	my $start_needle = '<input type="checkbox" name="chk" value="';
	$trackback_field =~ m/$start_needle(\d+?)-(\d+?)"/i;
	$postid = $1;
	$trackbackid = $2;

#	트랙백이 적혀진 글의 페이지 가져오기. - 수정 2009.01.11
#	트랙백이 프로그램이 시작하는 오늘 적혔다면 다시 읽어오기. - 2009-1-13
#	my $content = BackUpEgloos_Subs::getpage($blogurl . '/' . $postid);
#	예제.
#	<td width="80" align="center" class="black">2009/01/06</td></tr>
	my $content; # 해당 페이지
	$trackback_field =~ m/<td width="80" align="center" class="black">(\d{4})\/(\d{2})\/(\d{2})<\/td><\/tr>/i;
	my $temp_time = DateTime->new(year => $1, month  => $2, day => $3,
						hour => 0, minute => 0, second => 0, time_zone => 'Asia/Seoul');
#	24시간 안에 올라온 것인지 확인.
	if(DateTime->compare($temp_time, $dt_today) > 0)
	{
#		24시간 안에 올라온 것이기에 새롭게 받는다.
		my $content_html = BackUpEgloos_Subs::getpage($blogurl . '/' . $postid);
#		<!-- egloos content start -->(.*?)<!-- egloos content end -->
		$content_html =~ m/<!-- egloos content start -->(.*?)<!-- egloos content end -->/ig;
		$content = $1;
	}
	else
	{
#		그렇지 않기에 미리 저장한 곳에서 가져온다.
#		이글루스가 임시 조치한 글의 경우 목록에 글이 없다.
#		따라서 여기서 만들어 처리한다. - 2009-1-13, http://nosyu.pe.kr/1796
#		http://www.cs.mcgill.ca/~abatko/computers/programming/perl/howto/hash/
		if(exists $postid_index->{$postid})
		{
			$content = $all_post->[$postid_index->{$postid}]->{content_html};
		}
		else
		{
#			Post를 만든다.
#			이글루스가 닫았으니 글은 비공개, 댓글, 트랙백도 전부 닫기.
			my %open_close;
			$open_close{post} = 'private';
			$open_close{comment} = 0;
			$open_close{trackback} = 0;
			
			my $filename = 'data/' . $postid . '/content.xml';
			
#			post 변수 생성.
			my $the_post = PostClass->new($postid, $egloosinfo, 0, 0, %open_close);
			
#			xml 파일 쓰기.
			BackUpEgloos_Subs::write_post_xml($filename, $the_post);
			
#   		배열에 글 정보 저장.
			push @$all_post, $the_post;
			
#			배열 index 저장.
			$postid_index->{$postid} = scalar(@$all_post) - 1;
			
			BackUpEgloos_Subs::my_print("이글루스가 임시 조치한 글을 추가하였습니다.\n" . "URL : " . $egloosinfo->{blogurl} . "/" . $postid . " - 제목 : " . $the_post->{title} . "\n");
			open(OUT, ">>:encoding(utf8) " , 'Egloos_blind.txt') or die $!;
			print OUT $postid . ' : ' .$the_post->{title} . "\n\n";
			close(OUT);
		}
	}
	
	
#	예제.
#	<a href="http://NoSyu.egloos.com/4631722#409427"
	$start_needle = '<a href="' . $blogurl . '/' . $postid . '#' . $trackbackid;
	$content =~ m/$start_needle[^>]+>(.*?)<div class="comment_body"/i;
	my $trackback_html = $1;
	
#	예제.
#	Tracked from  <a href="http://www.sis.pe.kr/2252" target="_new"><strong>엔시스의  정보보호 따..</strong></a> at 2008/10/01 08:45 <a href="
#	2009-1-12 추가.
	if($trackback_html =~ m/Tracked from  <a href="(.*?)"[^>]+><strong>(.*?)<\/strong><\/a> at (\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})/i)
	{
		$href = $1;
		$blog_title = $2;
		$time = DateTime->new(year => $3, month  => $4, day => $5,
						hour => $6, minute => $7, second => 0, time_zone => 'Asia/Seoul');
		$time = $time->epoch();
	}
	else
	{
#		에러가 자주 나기에 리포트 용으로 만듬.
#		최근에는 잘 나타나지 않으나 그래도 남겨둠.
		BackUpEgloos_Subs::my_print("에러! : " . $postid ."의 트랙백 " . $trackbackid . "\n");
		BackUpEgloos_Subs::my_print('error.txt를 nosyu@nosyu.pe.kr으로 보내주시길 바랍니다.' . "\n");
		BackUpEgloos_Subs::print_txt("TrackbackClass__time\n\n" . $blogurl . '/' . $postid . '#' . $trackbackid . "\n\n" . $trackback_html . "\n\n" . $content . "\n\n" . $trackback_field); # 디버그용.
		die;
	}
	
	
#	예제.
#	<td width="435" class="black"><a href="http://NoSyu.egloos.com/4631722"  title="??개인정보에 대한 이야기는 어제 오늘의 이야기가 아니죠..지금 한국정보보호진흥원(이하 'KISA)에서 개인정보 클린 캠페인을 9.24~10.24일까지 한달간 하고 있습니다. 본 블로거도 정보보호에 관심 있는 만큼 참여 해 보기로 하였습니다. 혹시, 어렵다고 하시는 분들을 위하여 하나씩 소개해 드리겠습니다. ?1. 개인정보 클린 캠페인 홈페이지를 방문한다. http://p-clean.kisa.or.kr/ 홈페이지를 방문하면 아래와 같은 홍보와 ..." target="_new">개인정보 클린 캠페인 참여해 보니 - 대부분 게임싸이트더라</a></td>
	$trackback_field =~ m/<td width="435" class="black"><a href="[^"]+"  title="(.*?)" target="_new">(.*?)<\/a><\/td>/i;
	$description = $1;
	$post_title = $2;
	
#	&quot; -> "
	$description =~ s/&quot;/"/ig;

#	&quot; -> "
	$post_title =~ s/&quot;/"/ig;
	
	
#	주소 안의 자신의 블로그 주소를 새로운 것으로 바꿈.
	if(!('' eq $newblogurl))
	{
		if($href =~ m/$blogurl\/(\d{6,7})/ig)
		{
			my $new_postid = scalar(keys(%$postid_index)) - $postid_index->{$1};
			$href =~ s/$blogurl\/(\d{6,7})/$newblogurl\/$new_postid/ig;
		}
	}
	
	
#	셋팅.
	my $self = { url=>$href, title=>$post_title,
		site=>$blog_title, excerpt=>$description, received=>$time,
		postid=>$postid, id=>$postid . '#' . $trackbackid };
	
	bless ($self, $class);
	return $self;
}

#getset 함수들
sub description { $description }; # 본문
sub time { $time }; # 시간
sub href { $href }; # 주소
sub blog_title { $blog_title }; # 블로그 제목
sub post_title { $post_title }; # 카테고리

1;