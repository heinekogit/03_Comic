#!/usr/local/bin/perl

use strict;
use warnings;

use utf8;
binmode STDIN, 'encoding(cp932)';
binmode STDOUT, 'encoding(cp932)';
binmode STDERR, 'encoding(cp932)';
use Encode;

use Image::Size 'imgsize';


my @list;
my $dh;

my @log;
my @mate_folders;

my @shosi;
my @koumoku_content;
my @check_shosi;
my $check_shosi;
    
my $count_data;
my $count_shosi;

my @gazou_jpeg;
my @gazou_renban;


    
# 	 書誌リストと素材データの有無比較チェック		================================================================

# 	 素材フォルダ内部・Zフォルダのリスト化		---------------------------------------------

	$count_data = 0;

my $dir = "03_materials";

# ディレクトリオープン
	opendir $dh, $dir
  	or die "Can't open directory $dir: $!";

	while (my $list = readdir $dh) {
  		next if $list eq '.' || $list eq '..';
 	 	push @list, $list;
 	 
 	 	$count_data ++;
	}

#   	 print "素材データの1は". $list[0] . "\n";
#   	 print "素材データの2は". $list[1] . "\n";
		print "\n話フォルダのチェック　---------------------------------------------------------\n";		#ログの見やすさ整理
	   	 print "素材データの数は".$count_data . "\n";


#	shosi.csvの読み込み部分  	---------------------------------------------------------

	$count_shosi = 0;

	open(IN_SHOSI, "<:encoding(UTF-8)", "shosi.csv") or die "cant open shosi\n";
		@shosi = <IN_SHOSI>;
	close(IN_SHOSI);

	foreach(@shosi)  	 
  	  {
		@koumoku_content = split(/,/);
  		 
		push @check_shosi, $koumoku_content[47];

   	 	$count_shosi ++;
    }

#   	 print $check_shosi[0]."　書誌の１つめ\n";
   	 print "書誌の話数は".$count_shosi."\n";


#	書誌と素材フォルダ名の比較チェック  	   	--------------------------------------------
    
   	 my $i;
   	 my $shosi_match;
   	 
   	 for (@check_shosi) {

		print "書誌 " . $_ . "：";
		
		$shosi_match = $_;

   	 		$i = 0;
   	 	
			while ($i < @list) {

#				print "書誌".$shosi_match."は";

		   		if ($shosi_match ne $list[$i]) {
   	 				$i++;
   	 					if ($i == @list) {
   							print "$shosi_match は素材データが見当たりません\n";
										}   	 					
   	 				next;
  		 		} 
   		 		elsif ($shosi_match eq $list[$i]) {
     				 print "$shosi_match の素材データありok\n";
     				 last;
   				 } else {
   					print "$shosi_match は素材データなし\n";
   				 last;
				}
   				 print "\n";
				
  			}

	}



#  	  open(LOGS, ">:encoding(UTF-8)", "01_output/log.txt") or die "cant open log_file\n";  	  #002以降xhtmlファイルの出力
#  	  print LOGS @log;
#  	  close(LOGS);


