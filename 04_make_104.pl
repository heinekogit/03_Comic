#!/usr/local/bin/perl

use strict;
use warnings;

use utf8;
binmode STDIN, 'encoding(cp932)';
binmode STDOUT, 'encoding(cp932)';
binmode STDERR, 'encoding(cp932)';
use Encode;

use File::Path 'mkpath';
use File::Copy;
use File::Copy::Recursive qw(rcopy);
use File::Path qw(remove_tree);
#	use File::Path qw(rmtree);

use Image::Size 'imgsize';

use Text::CSV; 

use DateTime;
use DateTime::Format::ISO8601;


    my @img_list;
    my @xhtml_list;
    my @spine_list;

    my @shosi;
    my @koumoku_content;
    
    my @standard_opf;
    my @xhtml_one;

    my $page_count;
    my $image_count;
    my @tmp_var;
        
    my $gazou_count;    
    my $count;

    my @log;
    
	my @chosha_mei;
	my @chosha_katakana;
    my @chosha_temp;
    my @go_opf_chosha;
    
    my $ichi_height;
	my $width;
        
	my @mate_folders;

	my @cut_spine_list;	
	my @go_spine_list;

	my $template_content;

	my @mokuji_list;
	my @navig_list;
	my @go_mokuji;

	my @go_navpoint;
	my $mokuji_phrase;

	my @renamed_img;
	my @renamed_xhtml;
	my @pre_print_spine;

	my @xhtml_colophon;
	my $img_count;

	my @gazou_files;
    my @adjusted_spine;

	my $playOrder_end;

	my $mokuji_fuyou_pt1;
	my $mokuji_fuyou_pt2;
	my $mokuji_cut;

	my $output_file;


#	========================================================================================================

#　要新規の作り込み	-----------------------------------------------------
#	△	書誌配列の番号書き直し
#	△	opf見開きで左右方向の分岐
#			・ltrとrtl？（各行のright、leftが逆）
#	〇	著者数の分割
#	△	templateのstandard.opfをあちこち改修
#	〇	表紙・奥付画像の別処理
#			かなり後の方で、フォルダに放り込む（情報が取り込まれる・ファイル名変更などを避ける）
#	未	表紙・奥付のxhtml出力
#	未	入稿フォルダと出力ファイル名

#	中	全体整備	-----------------------------------------------------------
#			素材入りと置き場、処理フォルダ、フォルダ名とスクリプト整理

#	p-000画像、htmlがない（spineのみある）、処理考え
#	アップデート日の記入
#		use Time::Piece;
#		my $t = localtime;  # 現在の日時を取得
#		my $today = $t->ymd;  # "YYYY-MM-DD" 形式で日付を取得
#		print "Today is $today\n";	

#	===========================================================================================================
#	rmdir("05_output/$koumoku{'kd_num'}") or die "cant delete folder\n";		#未完成。データ残りあるとあるとエラーになるのであらかじめデータ除去。	

#	=========================================================================================================
#	opfに使うタグの、imgリスト & xhtmlリスト & spineリストの取り込み 

#    open(IN_IMG_LIST, "<:encoding(UTF-8)", "00_templates/opf_img.txt") or die "cant open img_list\n";
#    @img_list = <IN_IMG_LIST>;
#    close(IN_IMG_LIST);

#    open(IN_XHTML_LIST, "<:encoding(UTF-8)", "00_templates/opf_xhtml.txt") or die "cant open xhtml_list\n";
#    @xhtml_list = <IN_XHTML_LIST>;
#    close(IN_XHTML_LIST);
    
#    open(IN_SPINE_LIST, "<:encoding(UTF-8)", "00_templates/opf_spine.txt") or die "cant open spine_list\n";
#    @spine_list = <IN_SPINE_LIST>;
#    close(IN_SPINE_LIST);


#    shosi.csvの読み込み部分   	 ===========================================================================

my $file = '04_assemble/shosi.csv';
my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });

# CSVファイルを開く
open(IN_SHOSI, "<:encoding(UTF-8)", $file) or die "cant open $file: $!";
 @shosi = <IN_SHOSI>;
close(IN_SHOSI);


    foreach(@shosi) {
    @koumoku_content = split(/,/);

    &pre_check;
    &chosha_divide;
    &output_folders;
    &gazou_glob;
    &make_xhtml_one;
    &make_xhtml_extra;
    &make_xhtml_okuduke;
    &make_opf;
    &output_image_extra;

    # ここで呼び出す
    &make_xhtml_white;

    if($koumoku_content[12] eq "yes") {
        &make_mokuji;
    } else {
        &no_mokuji;
    }
    &output_txts;
    &remove_needless;
    &output_log;
}

     open(LOGS, ">:encoding(UTF-8)", "05_output/log.txt") or die "cant open log_file\n";   	 #002以降xhtmlファイルの出力
     print LOGS @log;
     close(LOGS);


# 事前チェック    ===========================================================================
    sub pre_check{
		
		opendir(DIRHANDLE, "04_assemble");		# ディレクトリエントリの取得

		foreach(readdir(DIRHANDLE)){
			next if /^\.{1,2}$/;				# '.'や'..'をスキップ
#			print "$_\n";
		}

		my $data = $koumoku_content[5];
		
		for (@mate_folders) {

		if ($_ eq $data){
  				print "ok\n";
			} else {
  				print "$data nai\n";
		}

		}


	}

# 画像情報を作成    ===========================================================================
    sub gazou_glob {

    # jpg のファイル数を取得
    @gazou_files = glob("05_output/$koumoku_content[5]/item/image/*.jpg");  # outputフォルダ内画像

    # ↓ここから置き換え
    my $serial = 1;
    foreach my $original_file (sort @gazou_files) {
        my $new_file_name = sprintf("05_output/$koumoku_content[5]/item/image/i-%03d.jpg", $serial);
        rename $original_file, $new_file_name or warn "リネーム失敗: $original_file -> $new_file_name";

        # 三桁ゼロ埋めでファイル名を生成
        my $serial_str = sprintf("%03d", $serial);

        # 画像タグを生成して配列にpush
        push @renamed_img, qq{<item media-type="image/jpeg" id="i-$serial_str" href="image/i-$serial_str.jpg"/>\n};
        # xhtmlタグを生成して配列にpush
        push @renamed_xhtml, qq{<item media-type="application/xhtml+xml" id="p-$serial_str" href="xhtml/p-$serial_str.xhtml" properties="svg" fallback="i-$serial_str"/>\n};
        # spine情報を生成して配列にpush
        # push @pre_print_spine, qq{<itemref linear="yes" idref="p-$serial_str" properties="page-spread-"/>\n};
		# 修正。spine情報を生成して配列にpush（page-spread- は含めない）
		push @pre_print_spine, qq{<itemref linear="yes" idref="p-$serial_str"/>};

        $serial++;
    }
    # ↑ここまで

    # 確定の画像数
    $gazou_count = $serial - 1;
    $page_count = $gazou_count - 1;

    # 配列を初期化
    @gazou_files = ();
}


#    表紙ページxhtmlの読み込み部分    ===========================================================================

    sub make_xhtml_one{
    
		open(IN_01, "<:encoding(UTF-8)", "00_templates/p-cover.xhtml") or die "cant open cover_xhtml\n";
		@xhtml_one = <IN_01>;
		close(IN_01);

#	i-001.jpg のサイズを取得    ------------------------------------

		my $zeroone = glob("05_output/$koumoku_content[5]/item/image/front_end/i-cover.jpg");   				#
   	# .jpg のサイズを取得
		($width, $ichi_height) = imgsize("05_output/$koumoku_content[5]/item/image/front_end/i-cover.jpg");		#パターンa	001を直で指定	イキ

#   	 print $xhtml_one[0];   						 #確認用

   	 foreach(@xhtml_one){

   			 &umekomi;   								 
  			s/▼縦サイズ▼/$ichi_height/g;   			#環境変数から用意
  			s/▼横サイズ▼/$width/g;   			 	#環境変数から用意_1030に幅700pix（仕様）戻しに伴い修正追加
#			$ichi_height =();

   		 }
    }


#    p-002.xhtml以降の作成部分    ===========================================================================

    sub make_xhtml_extra {

    # 画像ファイルを取得
    my @image_files = glob("05_output/$koumoku_content[5]/item/image/i-*.jpg");

    # 画像ファイルが存在しない場合のエラーチェック
    unless (@image_files) {
        die "画像ファイルが見つかりません: 05_output/$koumoku_content[5]/item/image/i-*.jpg";
    }

    # 各画像ファイルに対してループ処理
    foreach my $image_file (@image_files) {
        # ファイル名から番号部分を抽出
        my ($sanketa_name) = $image_file =~ /i-(\d+)\.jpg$/;

        unless (defined $sanketa_name) {
            warn "画像ファイル名に番号が見つかりません: $image_file";
            next;
        }

        # 画像サイズを取得
        my ($width, $two_after_height) = imgsize($image_file);
        unless (defined $width && defined $two_after_height) {
            warn "画像サイズを取得できません: $image_file";
            next;
        }

        # p-002のテンプレを読み込む
        open(IN_02, "<:encoding(UTF-8)", "00_templates/p-00n.xhtml") or die "cant open 02xhtml\n";
        my @xhtml_extra = <IN_02>;
        close(IN_02);

        # テンプレートに情報を埋め込む
        foreach (@xhtml_extra) {
            &umekomi;
            s/▼ファイル名数字▼/$sanketa_name/g;    # XHTML ファイル名
            s/▼縦サイズ▼/$two_after_height/g;      # 画像の高さ
            s/▼横サイズ▼/$width/g;                # 画像の幅
        }

        # p-002以降の XHTML ファイル名を生成
        my $file_count_name = "p-" . $sanketa_name . ".xhtml";

        # XHTML ファイルを出力
        open(OUT_02, ">:encoding(UTF-8)", "05_output/$koumoku_content[5]/item/xhtml/$file_count_name") or die "cant open xhtml_extra\n";
        print OUT_02 @xhtml_extra;
        close(OUT_02);
    }
}

#    奥付xhtmlの作成部分    ===========================================================================

    sub make_xhtml_okuduke {

		open(IN_OKU, "<:encoding(UTF-8)", "00_templates/p-colophon.xhtml") or die "cant open colophon_xhtml\n";
		@xhtml_colophon = <IN_OKU>;
		close(IN_OKU);

		foreach(@xhtml_colophon){

   			 &umekomi;   								 
  			s/▼縦サイズ▼/$ichi_height/g;   			#環境変数から用意
  		 s/▼横サイズ▼/$width/g;   			 	#環境変数から用意_1030に幅700pix（仕様）戻しに伴い修正追加
		}
	}

#    standard.opfの作成    ===========================================================================

    sub make_opf{   				 

   	 open(IN_STD, "<:encoding(UTF-8)", "00_templates/standard.opf")  or die "cant open opf\n";
   	 @standard_opf = <IN_STD>;
   	 close(IN_STD);

#   		 print $standard_opf[0];   											 #確認用

   	$image_count = $page_count - 1;
   				 
	&make_spine;

   	foreach(@standard_opf)   	 
   		 {
   			&umekomi;   												 #

   			s/▼著者情報テキスト挿入位置▼/join "", @go_opf_chosha/eg;   			 #サブルーチン chosha_divide の生成テキストを挿入

   			s/▼画像ファイルタグ印字位置▼/join "", @renamed_img/e;   			 #これがいちばんマシ

   		 s/▼xhtmlファイルタグ印字位置▼/join "", @renamed_xhtml/eg;   		 #環境変数から用意
 
   			s/▼spineタグ印字位置▼/join "", @adjusted_spine/eg;   				 #環境変数から用意。古い書き方
#   			s/▼spineタグ印字位置▼/join "", @pre_print_spine/eg;   				 #環境変数から用意。古い書き方
#			my $replacement = join "\n", @go_spine_list; 				# 改行で結合
#			s/▼spineタグ印字位置▼/$replacement/g;
   		 }
   		 
   	@go_opf_chosha = ();											#opfに埋め込む著者情報の配列を初期化
	@renamed_img = ();
	@renamed_xhtml = ();
	@pre_print_spine = ();
    @adjusted_spine = ();

    }


# 	サブルーチン　opf内のspine作成  	=========================================================================
#		ltr・rtlの分岐とleft・rightの交互出力

sub make_spine {
    my $left_property  = 'left';
    my $right_property = 'right';

    my $last_direction;

    for my $itemref (@pre_print_spine) {
        my ($idref) = $itemref =~ /idref="([^"]+)"/;
        next unless $idref;

        my $direction;

        if ($idref eq 'p-001') {
            # 最初のページは必ず左ページ
            $direction = $left_property;
        } else {
            # 前の方向を元に交互に設定（初期は right とする）
            $direction = (defined $last_direction && $last_direction eq $left_property)
                         ? $right_property
                         : $left_property;
        }

        $last_direction = $direction;

        push @adjusted_spine,
            qq{<itemref linear="yes" idref="$idref" properties="page-spread-$direction"/>\n};
    }

	# colophoをテンプレ作り付けの変更により、コメントアウト（07/16）
    # 奥付ページの方向は、直前と逆にする
#    my $final_direction = ($last_direction eq $left_property) ? $right_property : $left_property;
#    push @adjusted_spine,
#        qq{<itemref linear="yes" idref="p-colophon" properties="page-spread-$final_direction"/>\n};
}




#    出力    ===========================================================================

#    フォルダ・画像類の出力・コピー    ------------------------------------------

    sub output_folders{

#   	 $koumoku_name[4];   							 #話のファイル名

   	 mkdir("05_output/$koumoku_content[5]", 0755) or die "話のフォルダを作成できませんでした\n";
   	 mkdir("05_output/$koumoku_content[5]/item", 0755) or die "itemフォルダを作成できませんでした\n";
   	 mkdir("05_output/$koumoku_content[5]/META-INF", 0755) or die "META-INFのフォルダを作成できませんでした\n";
   	 mkdir("05_output/$koumoku_content[5]/item/xhtml", 0755) or die "xmlフォルダを作成できませんでした\n";
   	 mkdir("05_output/$koumoku_content[5]/item/style", 0755) or die "styleのフォルダを作成できませんでした\n";
   	 mkdir("05_output/$koumoku_content[5]/item/image", 0755) or die "話の画像のフォルダを作成できませんでした\n";

   	#    テンプレよりテキスト類のコピー    -----------    

   	 rcopy("00_templates/META-INF/container.xml","05_output/$koumoku_content[5]/META-INF") or die "container.xmlをコピーできません\n";
   	 rcopy("00_templates/mimetype","05_output/$koumoku_content[5]") or die "mimetypeをコピーできません\n";
   	 rcopy("00_templates/item/style","05_output/$koumoku_content[5]/item/style") or die "styleをコピーできません\n";

  	 #    画像ファイルコピー    -----------    

   	 rcopy("04_assemble/$koumoku_content[5]","05_output/$koumoku_content[5]/item/image") or die "$koumoku_content[5]の画像をコピーできません\n";
					#注意：英数字以外のファイル名が引っかかるっぽい

  	 #    shosi.csvを生成xhtml階層にログ的コピー保存    -----------    

   	 rcopy("04_assemble/shosi.csv","05_output") or die "shosiを履歴用にコピーできません\n";

    # 目次が必要な場合のみコピー
    if ($koumoku_content[12] eq "yes") {
        rcopy("04_assemble/$koumoku_content[5]/front_end/mokuji.csv","05_output") or warn "mokujiを履歴用にコピーできません\n";
    }

    }


	#    情報処理の後、本体以外（前付・後付）の画像配置   ------------------------------------------

    sub output_image_extra {
		rcopy("04_assemble/$koumoku_content[5]/front_end/i-cover.jpg","05_output/$koumoku_content[5]/item/image") or die "カバー画像をコピーできません\n";
		rcopy("04_assemble/$koumoku_content[5]/front_end/i-colophon.jpg","05_output/$koumoku_content[5]/item/image") or die "奥付画像をコピーできません\n";
		rcopy("00_templates/i-white.jpg","05_output/$koumoku_content[5]/item/image")
	}


    #    テキスト類の出力    ----------------------------------------------------------------------------
    
   	 sub output_txts{

		open(OUT_STD, ">:encoding(UTF-8)", "05_output/$koumoku_content[5]/item/standard.opf") or die "cant make opf\n";   		 #opfファイルの出力
		print OUT_STD @standard_opf;
		close(OUT_STD);

		open(OUT_01, ">:encoding(UTF-8)", "05_output/$koumoku_content[5]/item/xhtml/p-cover.xhtml") or die "cant make cover_xhtml\n";   	 #001のxhtmlファイルの出力
		print OUT_01 @xhtml_one;
		close(OUT_01);

		open(OUT_END, ">:encoding(UTF-8)", "05_output/$koumoku_content[5]/item/xhtml/p-colophon.xhtml") or die "cant make okuduke\n";   	 #001のxhtmlファイルの出力
		print OUT_END @xhtml_colophon;
		close(OUT_END);

    }

	#	不要フォルダの削除    ----------------------------------------------------------------------------

	sub remove_needless {

		my $directory = "05_output/$koumoku_content[5]/item/image/front_end";  # 削除したいディレクトリのパス

		# フォルダ内のファイルを取得
			opendir(my $dh, $directory) or die "can't opendir $directory: $!";
			my @files = grep { -f "$directory/$_" } readdir($dh);
			closedir $dh;

		# ファイルを削除
		foreach my $file (@files) {
    		my $path = "$directory/$file";
    		unlink $path or warn "unlink $path failed: $!";
		}

		# フォルダが空かどうかを再度確認
		if (not glob("$directory/*")) {
    		print "Directory $directory is now empty.\n";
		} else {
    		print "Failed to delete all files in directory $directory.\n";
		}

		# ディレクトリを削除
			remove_tree($directory, { error => \my $err });

		# エラーチェック
			if (@$err) {
				for my $diag (@$err) {
				my ($file, $message) = %$diag;
					if ($file eq '') {
            			print "General error: $message\n";
        			} else {
            			print "Problem unlinking $file: $message\n";
        			}
    			}
			} else {
				    print "Directory $directory removed successfully.\n";
			}
	}


# サブルーチン　文字変換    ===========================================================================

sub umekomi {
    my $aki = "　";  # 初期値として全角スペース

    s/●タイトル名●/$koumoku_content[0]/g;   			 #2L以上は使わない
#    s/●話巻順番●/$koumoku_content[1]/g;   			 #2L以上は使わない
    s/●タイトル名カタカナ●/$koumoku_content[4]/g;   	 #2L以上は使わない
    s/●話数3桁●/$koumoku_content[2]/g;   			 	#2L以上は使わない

    s/●出版社名●/$koumoku_content[21]/g;   			 #2L以上は使わない
    s/●出版社名カタカナ●/$koumoku_content[23]/g;   	 #2L以上は使わない

	$mokuji_fuyou_pt1 = '<item media-type="application/x-dtbncx+xml" id="ncx" href="toc.ncx"/>';
	$mokuji_fuyou_pt2 = ' toc="ncx"';

	if ($koumoku_content[12] ne "yes") {
		s/\Q$mokuji_fuyou_pt1\E//;			# 正規表現の中で変数を展開する際は、// を \Q...\E で囲む
		s/\Q$mokuji_fuyou_pt2\E//;
	} 

    s/●読み方向●/$koumoku_content[8]/g;   	 #2L以上は使わない

	# 現在の日時を取得
	my $dt = DateTime->now;
	# ISO 8601形式で出力
	my $iso8601_string = $dt->iso8601 . 'Z';
    s/●作業日時●/$iso8601_string/g;   	 

    s/●基準幅●/$koumoku_content[15]/g;   	 
    s/●基準高●/$koumoku_content[16]/g;   	

    # 巻名・話数名、その前アキを制御 -----------------------------------------------
    my $notate = "";

    if (defined $koumoku_content[1] && $koumoku_content[1] ne '') {
        # [18]（アキ制御）が「有」なら全角アキ
        $notate .= "　" if defined $koumoku_content[18] && $koumoku_content[18] eq '有';
        # [19]（第/No.など）が空欄でなければ追加
        $notate .= $koumoku_content[19] if defined $koumoku_content[19] && $koumoku_content[19] ne '';
        # 巻番号（[1]）は必ず追加
        $notate .= $koumoku_content[1];
        # [20]（巻など）が空欄でなければ追加
        $notate .= $koumoku_content[20] if defined $koumoku_content[20] && $koumoku_content[20] ne '';
    } else {
        # [1]がブランクなら何も連結しない（または必要なら別の処理）
        $notate = '';
    }

    $notate =~ s/\R//g;
	s/●話巻順番●/$notate/g;
}


# サブルーチン　ログ出力    ===========================================================================

    sub output_log{

   	 push(@log, "$koumoku_content[5]," . "$koumoku_content[5],". "$koumoku_content[2]\n");   		#0901 update

	}


# サブルーチン　著者分割    ===========================================================================
#	12から23が著者名と著者名カタカナに交互に並ぶ。
#	人数分出力と、カウント回し

    sub chosha_divide{
    
    	  @chosha_mei = ($koumoku_content[24], 
		 					$koumoku_content[26], 
		  					$koumoku_content[28], 
							$koumoku_content[30], 
							$koumoku_content[32], 
							$koumoku_content[34]);    	  
    	  @chosha_katakana = ($koumoku_content[25], 
								$koumoku_content[27], 
								$koumoku_content[29], 
								$koumoku_content[31], 
								$koumoku_content[33], 
								$koumoku_content[35]);

		my @chosha_meibo;  # 空の配列を初期化する

		# 特定のインデックスから始まる要素をチェックし、カラであればループを終了する
			for my $index (24, 26, 28, 30, 32, 34) {
   				my $element = $koumoku_content[$index];
				last unless defined $element && $element ne '';  # カラでないことをチェックしてループを終了する
    			push @chosha_meibo, $element;  # 配列に要素を追加する
			}

			my $chosha_counter = 0;

   		 while ($chosha_counter < @chosha_meibo){
   			 
				my $fig_counter = $chosha_counter + 1;
#				print $fig_counter . "回目\n";
				
    			open(CHOSHA_TEMP, "<:encoding(UTF-8)", "00_templates/opf_choshamei.txt") or die "cant open opf_choshamei\n";		#著者情報のテンプレを読み込み
   	 			@chosha_temp = <CHOSHA_TEMP>;
    			close(CHOSHA_TEMP);

				foreach(@chosha_temp){

						s/●作家名●/$chosha_mei[$chosha_counter]/g;   			 						#サブルーチンに移管
						s/●作家名カタカナ●/$chosha_katakana[$chosha_counter]/g;   							#サブルーチンに移管
						s/▼作家順番▼/$fig_counter/g;
				}

   				push(@go_opf_chosha, @chosha_temp);
    	     	@chosha_temp = ();

    	     	$chosha_counter ++;
    	     	   	     
  		 	}
	}



# 	サブルーチン　目次のnavigation-documents.xhtml作成  	===========================================================================
#	
	sub make_mokuji	{

		# 目次テキストを読み込む
			open(IN_MOKUJI_LIST, "<:encoding(UTF-8)", "04_assemble/$koumoku_content[5]/front_end/mokuji.csv") or die "can't open mokuji_csv\n";
			my @mokuji_list = <IN_MOKUJI_LIST>;
			close(IN_MOKUJI_LIST);

		&make_tocncx;			#	toc.ncxのサブルーチンへ

			open(IN_NAVIG_LIST, "<:encoding(UTF-8)", "00_templates/navigation-documents.xhtml") or die "can't open navigation_documents_xhtml\n";
			my @navig_list = <IN_NAVIG_LIST>;
			close(IN_NAVIG_LIST);

		# 目次行のテンプレート
			my $temp_row = '<li><a href="xhtml/p-%03d.xhtml">%s</a></li>';

		# 目次リストを処理して新しい配列に追加
			my @go_mokuji;

			foreach my $line (@mokuji_list) {
				chomp($line);  # 改行を削除
				my ($mokuji_phrase, $nonble) = split(/,/, $line);  # カンマで分割
				$nonble =~ s/^\s+|\s+$//g;  # 数値の前後の空白を削除
				if ($nonble =~ /^\d+$/) {  # 数値チェック
					push @go_mokuji, sprintf $temp_row, $nonble, $mokuji_phrase;
				} else {
					warn "Invalid page number '$nonble' in line: $line\n";
				}
			}

		# navigation-documents.xhtmlのテンプレートを処理
			foreach my $line (@navig_list) {
				$line =~ s/▼目次行印字位置▼/join("\n", @go_mokuji)/eg;  # 目次行を挿入
			}

			foreach (@navig_list) {
				s/●目次xhtmlファイル名●/$koumoku_content[7]/g;   	 #2L以上は使わない
			}


		# 処理されたテンプレートを出力（必要に応じてファイルに書き出し）
		open(OUT_NAVIG_LIST, ">:encoding(UTF-8)", "05_output/$koumoku_content[5]/item/navigation-documents.xhtml") or die "can't open output file\n";
		print OUT_NAVIG_LIST @navig_list;
		close(OUT_NAVIG_LIST);
	
	}


#   サブルーチン　旧目次仕様 toc.ncxの作成    ===========================================================================

    sub make_tocncx{   				 

		# ファイルを読み込む
		my $csv_file = "04_assemble/$koumoku_content[5]/front_end/mokuji.csv";
		my $template_file = "00_templates/toc_ncx_navPoint.txt";
		my $ncx_file = "00_templates/toc.ncx";
		my $output_file = "05_output/$koumoku_content[5]/item/toc.ncx";

		open(my $fh_csv, "<:encoding(UTF-8)", $csv_file) or die "can't open $csv_file: $!";
		open(my $fh_template, "<:encoding(UTF-8)", $template_file) or die "can't open $template_file: $!";
		open(my $fh_ncx, "<:encoding(UTF-8)", $ncx_file) or die "can't open $ncx_file: $!";

		my @mokuji_list = <$fh_csv>;
		close($fh_csv);

		my $template = do { local $/; <$fh_template> };
		close($fh_template);

		my @ncx_content = <$fh_ncx>;
		close($fh_ncx);

		# 目次の各行を処理してテンプレートに挿入
			my $playOrder = 1;
			my $navPoint_id = 1;;
			my @navPoints;

		foreach my $line (@mokuji_list) {
		    chomp($line);
	    	my ($title, $page) = split(/,/, $line);
    		my $id = sprintf("p-%03d", $page);
    		my $navPoint = $template;
    		$navPoint =~ s/●navPoint_id●/xhtml-n-$navPoint_id/g;
	    	$navPoint =~ s/▼playOrder順番▼/$playOrder/g;
    		$navPoint =~ s/●目次項目●/$title/g;
	    	$navPoint =~ s/●xhtmlファイル名●/$id.xhtml/g;
	    	push @navPoints, $navPoint;
    		$playOrder++;
    		$navPoint_id++;
		}

		$playOrder_end = $playOrder;

		# ncxファイルの内容に目次を埋め込む
		my $navPoints_text = join("\n", @navPoints);
		foreach my $line (@ncx_content) {
    		$line =~ s/▼navPointタグ印字位置▼/$navPoints_text/eg;

			$line =~ s/●playorder_end●/$playOrder_end/g;
		}

		# 処理された内容を出力ファイルに書き出し
		open(my $fh_output, ">:encoding(UTF-8)", $output_file) or die "can't open $output_file: $!";
		print $fh_output @ncx_content;
		close($fh_output);

	}

# 	サブルーチン　目次を作らない 	===========================================================================
#		navigation-documents.xhtmlの目次をカット & toc.ncxを作らない

	sub no_mokuji {

			open(GET_NAVIG_LIST, "<:encoding(UTF-8)", "00_templates/navigation-documents.xhtml") or die "can't open navigation_documents_xhtml\n";
			my @navigate_list = <GET_NAVIG_LIST>;
			close(GET_NAVIG_LIST);

			$mokuji_cut = '<li><a epub:type="toc" href="xhtml/p-●目次xhtmlファイル名●.xhtml">目次</a></li>';


				foreach(@navigate_list){

						s/▼目次行印字位置▼//g;   			 						#サブルーチンに移管
						s/$mokuji_cut//;   							#サブルーチンに移管
				}

		open(PUT_NAVIG_LIST, ">:encoding(UTF-8)", "05_output/$koumoku_content[5]/item/navigation-documents.xhtml") or die "can't open output file\n";
		print PUT_NAVIG_LIST @navigate_list;
		close(PUT_NAVIG_LIST);

	}


sub make_xhtml_white {
    my $white_img    = "00_templates/i-white.jpg";
    my $template_src = "00_templates/p-00n.xhtml";
    my $output_file  = "05_output/$koumoku_content[5]/item/xhtml/p-white.xhtml";

    # 画像サイズ取得
    unless (-f $white_img) {
        warn "i-white.jpg が見つかりません: $white_img";
        return;
    }

    my ($width, $height) = imgsize($white_img);
    unless (defined $width && defined $height) {
        warn "i-white.jpgの画像サイズを取得できません: $white_img";
        return;
    }

    # テンプレート読み込み
    open(my $in, "<:encoding(UTF-8)", $template_src) or die "can't open $template_src\n";
    my @white_xhtml = <$in>;
    close($in);

    # テンプレート置換
    foreach (@white_xhtml) {
        # &umekomi(); ← 必要であればここで呼ぶ
    	s/●タイトル名●/$koumoku_content[0]/g;   			 #2L以上は使わない
        s/▼ファイル名数字▼/white/g;
        s/▼縦サイズ▼/$height/g;
        s/▼横サイズ▼/$width/g;

    # 巻名・話数名、その前アキを制御 -----------------------------------------------
    my $notate = "";

    if (defined $koumoku_content[1] && $koumoku_content[1] ne '') {
        # [18]（アキ制御）が「有」なら全角アキ
        $notate .= "　" if defined $koumoku_content[18] && $koumoku_content[18] eq '有';
        # [19]（第/No.など）が空欄でなければ追加
        $notate .= $koumoku_content[19] if defined $koumoku_content[19] && $koumoku_content[19] ne '';
        # 巻番号（[1]）は必ず追加
        $notate .= $koumoku_content[1];
        # [20]（巻など）が空欄でなければ追加
        $notate .= $koumoku_content[20] if defined $koumoku_content[20] && $koumoku_content[20] ne '';
    } else {
        # [1]がブランクなら何も連結しない（または必要なら別の処理）
        $notate = '';
    }

    $notate =~ s/\R//g;
	s/●話巻順番●/$notate/g;

    }

    # 出力ディレクトリの作成（必要に応じて）
    my ($output_dir) = $output_file =~ m{^(.+)/[^/]+$};
    unless (-d $output_dir) {
        require File::Path;
        File::Path::make_path($output_dir) or die "Failed to create $output_dir\n";
    }

    # 出力
    open(my $out, ">:encoding(UTF-8)", $output_file) or die "can't write $output_file\n";
    print $out @white_xhtml;
    close($out);
}





