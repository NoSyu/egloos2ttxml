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
my $is_menu_page = 0;		# 이글루스에 새로 추가된 것으로 메뉴릿이라고 하는 것이 있다. 이것의 경우 댓글 아이디 체계가 기존의 것과 반대로 되어 있다.
# 따라서 이것을 보고 TTXML 작성할 때 댓글을 쓸 방향을 정해야 한다. 
# 0이면 일반 글, 1이면 메뉴릿

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
		# 웹페이지의 자료를 가져옴. 모바일 페이지의 것을 가져옴.
		my $content_html = BackUpEgloos_Subs::getpage($egloosinfo->{blogurl} . '/m/' . $postid, 0);
		
		# 변수 할당		
		$title = BackUpEgloos_Subs::findstr($content_html, '<div class="subject"><h3>(?:<img[^>]*> )?', '</h3>');
		$link = $egloosinfo->{blogurl} . '/' . $postid;
		$description = BackUpEgloos_Subs::findstr($content_html, '<div class="contents">', '<div class="wrap_tag">');
		if($content_html =~ m/<span class="cate"><a [^>]+>(.*?)<\/a>/ig)
		{
			$category = $1;
		}
		else
		{
			$category = '미분류';
		}
		# <span class="name">dongdm</span> 2010/12/30 23:41                </p>
		# <span class="name">dongdm</span> 1시간전                </p>
		# 이런 것도 있기에 난감. 그냥 저런 건 00:00으로 처리한다.
		$time = BackUpEgloos_Subs::findstr($content_html, '<span class="name">(?:.*?)</span>', '</p>');
		$time =~ /(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})/i;
		if(!$5)
		{
			# 01/02 10:25 방식도 있음
			if($time =~ /(\d{2})\/(\d{2}) (\d{2}):(\d{2})/i)
			{
				# year는 프로그램이 돌아가는 시점의 년도로 처리
				my $now_year = (localtime(time))[5];
				$now_year += 1900;
				$time = DateTime->new(year => $now_year, month  => $1, day => $2,
						hour => $3, minute => $4, second => 0, time_zone => 'Asia/Seoul');
			}
			else
			{
				# 1시간전 이런 식임.
				if($open_close{datetime_info} =~ /(\d{4})\/(\d{2})\/(\d{2})/i)
				{
					$time = DateTime->new(year => $1, month  => $2, day => $3,
						hour => 0, minute => 0, second => 0, time_zone => 'Asia/Seoul');
					BackUpEgloos_Subs::print_txt('글 : ' . $postid . "이 적힌 시간이 최근이라 시간 정보가 명확하지 않습니다.\n그렇기에 글이 적힌 시각이 0시 0분 0초로 하였습니다.\n에러가 아니기에 프로그램은 계속 진행됩니다.");
				}
				else
				{
					# 1시간전 이런 식이면서 메뉴릿 등이라 글 리스트에 나타나지 않음.
					$time = DateTime->now(time_zone => 'Asia/Seoul');
					BackUpEgloos_Subs::print_txt('글 : ' . $postid . "이 적힌 시간이 최근이며 이글루 관리 글 목록에 없습니다.\n그렇기에 글이 적힌 시각을 현재 시각으로 하였습니다.\n에러가 아니기에 프로그램은 계속 진행됩니다.");
				}
			}			
		}
		else
		{
			$time = DateTime->new(year => $1, month  => $2, day => $3,
				hour => $4, minute => $5, second => 0, time_zone => 'Asia/Seoul');
		}
		$time = $time->epoch();

#		글 공개여부.
		$visibility = $open_close{post};
#		트랙백, 댓글 공개여부. 
		$acceptComment = $open_close{comment};
		$acceptTrackback = $open_close{trackback};
#		트랙백, 댓글 개수
		if(0 == $acceptComment)
		{
			# 댓글을 더 이상 쓸 수 없기에 관리 페이지에 나오지 않음.
			$comment_count = 0;	# 기본적으로 0
			# 그리고 찾음.
			# 이렇게 하는 이유는 댓글이 0인 경우 해당 글에서 댓글 개수를 아예 보여주지 않음.
			# 예제
			# <div class="reply"><a href="/m/comment/2500689">덧글 <span> 17</span></a><span class="line">&nbsp;</span> <a href="/m/trackback/2500689">관련글 <span>3</span></a>                </div>            </div>
			if($content_html =~ m/<div class="reply"><a[^>]*?>덧글 <span> ([0-9]+?)<\/span>/ig)
			{
				# 찾았기에 찾은 내용물을 반환.
				$comment_count = $1;
			}
		}
		else
		{
			$comment_count = $open_close{comment_cnt};
		}
		
		if(0 == $acceptTrackback)
		{
			# 트랙백을 더 이상 쓸 수 없기에 관리 페이지에 나오지 않음.
			$trackback_count = 0;	# 기본적으로 0
			# 그리고 찾음.
			# 이렇게 하는 이유는 댓글이 0인 경우 해당 글에서 댓글 개수를 아예 보여주지 않음.
			# 예제
			# <div class="reply"><a href="/m/comment/2500689">덧글 <span> 17</span></a><span class="line">&nbsp;</span> <a href="/m/trackback/2500689">관련글 <span>3</span></a>                </div>            </div>
			if($content_html =~ m/<a href="\/m\/trackback\/$postid">관련글 <span>([0-9]+?)<\/span>/ig)
			{
				# 찾았기에 찾은 내용물을 반환.
				$trackback_count = $1;
			}
		}
		else
		{
			$trackback_count = $open_close{trackback_cnt};
		}
		
#		postid로 디렉토리 만들기. - 있는 경우 처리.
		if(!(-e './data/' . $postid))
		{
			mkdir('./data/' . $postid) or die "폴더 만들기 에러.\n";
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

		my $get_data_html;
		
		# 모바일을 이용하기에 모든 댓글과 트랙백을 여기에 붙인다.
		# 스킨 2.0
		# http://dongdm.egloos.com/m/comment/2510447/page/1
		my $comment_count_i = $comment_count;
		my $cmt_page = 1;
		my $comments_src = $egloosinfo->{blogurl} . '/m/comment/' . $postid . '/page/';
		
		while($comment_count_i > 0)
		{
			# 가져오기.
			$get_data_html = BackUpEgloos_Subs::getpage($comments_src . $cmt_page, 0);
			
			# 댓글 부분만 뽑아내기
			$get_data_html = BackUpEgloos_Subs::findstr($get_data_html, '<!-- comment -->', '<!-- reply_write -->');
			
			# 붙이기.
			# 기존의 것과 연결해서 붙여넣기.
			$content_html = $content_html . $get_data_html;
			
			# 루프 다음 것 처리.
			$comment_count_i -= 10;
			$cmt_page++;
		}
		
		# 트랙백 가져와서 붙이기			
		my $trackback_count_i = $trackback_count;
		$cmt_page = 1;
		my $trackback_src = $egloosinfo->{blogurl} . '/m/trackback/' . $postid . '/page/';
		
		while($trackback_count_i > 0)
		{
			# 가져오기.
			$get_data_html = BackUpEgloos_Subs::getpage($trackback_src . $cmt_page, 0);
			
			# 트랙백 부분만 뽑아내기
			$get_data_html = BackUpEgloos_Subs::findstr($get_data_html, '<!-- comment -->', '<ul class="pagination_view">');
			
			# 붙이기.
			# 기존의 것과 연결해서 붙여넣기.
			$content_html = $content_html . $get_data_html;
			
			# 루프 다음 것 처리.
			$trackback_count_i -= 10;
			$cmt_page++;
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
		$description = changeimgsrc_m($description, $postid);
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
		content_html=>$content_html, is_menu_page=>$is_menu_page};
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

	my $i = $file_count + 1; # 다운로드 받은 것들의 이름. _m 뒤를 이어서 진행되기에...
	my $ori_post_html = $description; # 원본 페이지.
	
	
	# 본문 안의 이미지 다운로드
	while($description =~ m/<img((?:.*?)src="(http:\/\/[[:alnum:][:punct:]^>^<^"^']+\.(jpg|png|gif|jpeg))"[^>]*)>/igc)
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
			$ori_post_html =~ s/<img(?:.*?)src="$img_url"[^>]*>/$img_dest/ig; # 이름 바꾸기.
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

# 포스트 안의 img 태그에 있는 src를 바꾼다.(다운로드 받아서)
# 이미지 뿐만 아니라 zip, pdf도 처리한다.
sub changeimgsrc_m($$)
{
#	본문 안의 내용, post id 
	my ($description, $postid) = @_;
	# 다운로드 받아 저장할 src : 'pic/postid_XXX.jpg(png 등)'

	my $i = 1; # 다운로드 받은 것들의 이름. 1부터 시작
	my $ori_post_html = $description; # 원본 페이지.
	
	# 본문 안의 이미지 다운로드
	# http://pds19.egloos.com/pds/201007/08/11/a0030011_4c35d1f77e1ad.jpg
	# http://thumb.egloos.net/460x0/http://pds19.egloos.com/pds/201007/08/11/a0030011_4c35d1f77e1ad.jpg
	# <img border="0" src="http://thumb.egloos.net/460x0/http://pds19.egloos.com/pds/201007/08/11/a0030011_4c35d1f77e1ad.jpg" width="300" alt="500" onclick="egloo_img_resize(this, 'http://pds19.egloos.com/pds/201007/08/11/a0030011_4c35d1f77e1ad.jpg');" />
	while($description =~ m/<img ((?:.*?) onclick="egloo_img_resize\(this, '(http:\/\/[[:alnum:][:punct:]^>^<^"^']+\.(jpg|png|gif|jpeg))'[^>]*)>/igc)
	{
#		예제.
#		<img border="0" src="http://thumb.egloos.net/460x0/http://pds19.egloos.com/pds/201007/08/11/a0030011_4c35d1f77e1ad.jpg" width="300" alt="500" onclick="egloo_img_resize(this, 'http://pds19.egloos.com/pds/201007/08/11/a0030011_4c35d1f77e1ad.jpg');" />
#		$img_url = http://pds19.egloos.com/pds/201007/08/11/a0030011_4c35d1f77e1ad.jpg
#		$img_extension = jpg
		my $img_info_html = $1; # 그림 정보.
		my $img_url = $2; # 그림 url
		my $img_extension = $3; # 그림 파일 확장자
		my $width = ''; # 그림 넓이.
		my $height = ''; # 그림 높이.
		my $alt = ''; # 그림 설명.
		
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
			$ori_post_html =~ s/<img (?:.*?) onclick="egloo_img_resize\(this, '$img_url'[^>]*>/$img_dest/ig; # 이름 바꾸기.
			$i++; # 파일명을 하나 증가.
		}
	} # end of  foreach my $img_elem (@img_elems)
	
	$file_count = $i-1; # 파일 개수 지정.
	return $ori_post_html; # 이미지 주소를 바꾼 본문 내용을 반환.
}

1;