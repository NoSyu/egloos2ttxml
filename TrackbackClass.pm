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

#	관리 페이지에서 트랙백 보낸 곳의 정보 가져오기
	$start_needle = '<td width="160" align="center" class="black"><a href="';
	$trackback_field =~ m/$start_needle(.+?)"[^>]+>(.+?)<\/a>/i;
	$href = $1;
	$blog_title = $2;
	
#	예제.
#	<td width="435" class="black"><a href="http://NoSyu.egloos.com/4631722"  title="??개인정보에 대한 이야기는 어제 오늘의 이야기가 아니죠..지금 한국정보보호진흥원(이하 'KISA)에서 개인정보 클린 캠페인을 9.24~10.24일까지 한달간 하고 있습니다. 본 블로거도 정보보호에 관심 있는 만큼 참여 해 보기로 하였습니다. 혹시, 어렵다고 하시는 분들을 위하여 하나씩 소개해 드리겠습니다. ?1. 개인정보 클린 캠페인 홈페이지를 방문한다. http://p-clean.kisa.or.kr/ 홈페이지를 방문하면 아래와 같은 홍보와 ..." target="_new">개인정보 클린 캠페인 참여해 보니 - 대부분 게임싸이트더라</a></td>
	$trackback_field =~ m/<td width="435" class="black"><a href="[^"]+"  title="(.*?)" target="_new">(.*?)<\/a><\/td>/i;
	$description = $1;
	$post_title = $2;
	
#	트랙백이 적혀진 글의 페이지 가져오기. - 수정 2009.01.11
#	트랙백이 프로그램이 시작하는 오늘 적혔다면 다시 읽어오기. - 2009-1-13
	my $content; # 해당 페이지
	
#	이글루스가 임시 조치한 글의 경우 목록에 글이 없다.
#	따라서 여기서 만들어 처리한다. - 2009-1-13, http://nosyu.pe.kr/1796
#	http://www.cs.mcgill.ca/~abatko/computers/programming/perl/howto/hash/
	if(exists $postid_index->{$postid})
	{
		$content = $all_post->[$postid_index->{$postid}]->{content_html};
	}
	else
	{
#		Post를 만든다.
#		이글루스가 닫았으니 글은 비공개, 댓글, 트랙백도 전부 닫기.
		my %open_close;
		$open_close{post} = 'private';
		$open_close{comment} = 0;
		$open_close{trackback} = 0;
		
		my $filename = 'data/' . $postid . '/content.xml';
		
#		post 변수 생성.
		my $the_post = PostClass->new($postid, $egloosinfo, 0, 0, %open_close);
		
#		xml 파일 쓰기.
		BackUpEgloos_Subs::write_post_xml($filename, $the_post);
		
#   	배열에 글 정보 저장.
		push @$all_post, $the_post;
		
#		배열 index 저장.
		$postid_index->{$postid} = scalar(@$all_post) - 1;
		
		BackUpEgloos_Subs::my_print("이글루스가 임시 조치한 글을 추가하였습니다.\n" . "URL : " . $egloosinfo->{blogurl} . "/" . $postid . " - 제목 : " . $the_post->{title} . "\n");
		open(OUT, ">>:encoding(utf8) " , 'Egloos_blind.txt') or die $!;
		print OUT $postid . ' : ' .$the_post->{title} . "\n\n";
		close(OUT);
	}	

#	time이 해결되지 않았음. 그래서 본문에서 가져와야 함.
#	<div class="trackback_list">
#                    <em><a href="http://dongdm.egloos.com/m/2500625" target="_blank" class="trackback_title">Yes! No!</a></em><br />
#                    <span>2010/01/16 13:46</span>
#                    <p>
#                        google_ad_client = "pub-7048624575756403";google_ad_slot = "1900030367";google_ad_width = 300;google_ad_height = 250;Thereare some difference between Korean and English grammar. The order ofsentence element is different. For example, translating dire... 
#                        <a href="#" class="btn_delete" title="삭제" onclick="delTrackback('572785', '2500689', 'a0030011');" >삭제</a>
#                    </p>
#
#                </div>

	my $temp_href = $href;
	if($temp_href =~ m/http:\/\/(.*?)\.egloos\.com(.*?)$/i)
	{
		$temp_href = 'http://' . $1 . '.egloos.com/m' . $2;
	}

	$start_needle = '<em><a href="' . $temp_href . '" target="_blank" class="trackback_title">(?:.*?)</a></em><br /><span>';
	my $end_needle = "'" . $trackbackid . "', '" . $postid . "'";
	#if($content =~ m/$start_needle(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})<\/span>(?:.*)delTrackback\($end_needle/i)
	if($content =~ m/<span>(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})<\/span>((?:(?!onclick="delTrackback\('(?!$trackbackid)[0-9]+?', '$postid').)*?)onclick="delTrackback\($end_needle/i)
	{
		# 찾았기에 입력한다.
		$time = DateTime->new(year => $1, month  => $2, day => $3,
						hour => $4, minute => $5, second => 0, time_zone => 'Asia/Seoul');
	}
	elsif($content =~ m/<span>(\d{2})\/(\d{2}) (\d{2}):(\d{2})<\/span>((?:(?!onclick="delTrackback\('(?!$trackbackid)[0-9]+?', '$postid').)*?)onclick="delTrackback\($end_needle/i)
	{
		# 올해의 것
		$time = DateTime->new(year => DateTime->now()->year(), month  => $1, day => $2,
						hour => $3, minute => $4, second => 0, time_zone => 'Asia/Seoul');
	}
	else
	{
		# 못 찾았기에 관리 페이지에 있는 것을 한다. 이것은 0시 0분 0초가 된다.
		$trackback_field =~ m/<td width="80" align="center" class="black">(\d{4})\/(\d{2})\/(\d{2})<\/td><\/tr>/i;
		$time = DateTime->new(year => $1, month  => $2, day => $3,
						hour => 0, minute => 0, second => 0, time_zone => 'Asia/Seoul');
		
		BackUpEgloos_Subs::print_txt("트랙백 시각을 제대로 가져오지 못했기에 관리 페이지에 있는 정보로만 입력합니다.\n" . "URL : " . $egloosinfo->{blogurl} . "/" . $postid . '#' . $trackbackid . "\n");
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

# 이런 태그를 처리하는 함수가 있을 것으로 추정되나 찾을 수 없음.
	#	&quot; -> "
		$post_title =~ s/&quot;/"/ig;
	#	&lt; -> <
		$post_title =~ s/&lt;/</ig;
	#	&gt; -> >
		$post_title =~ s/&gt;/>/ig;
	#	&amp; -> &
		$post_title =~ s/&amp;/&/ig;	
	
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