#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use File::Copy qw(copy);
use File::Path qw(make_path);
use Encode;

=begin comment
----------------------------------------------------------------------------------
■スクリプト［03_distribute_series_images_01.pl］の扱い方

（範囲）
・シリーズ（複数巻）を処理する素材フォルダ群を作成後、
　「04_assemble」直下に cover_XX.jpg / colophon_XX.jpg を配置する。
・その後、このスクリプトを実行することで、
　各 fukushuXX フォルダ内に front_end フォルダが作られ、画像がコピーされる。
・単巻・単話制作時は本スクリプトは使用せず、必要に応じて画像を手動配置する。

（処理内容）
・cover_XX.jpg、colophon_XX.jpgの一連のカバー・奥付画像を［04_assemble］以下に配置
・［front_end］フォルダを、［04_assemble］以下の各タイトル素材フォルダの中に自動生成
・shosiから、
	各タイトル素材フォルダごとの処理
		・フォルダ末尾の連番と同じ末尾連番を持つカバー・奥付画像ファイルを把握・コピー
		・［front_end］内に格納
		・［front_end］内の各画像名の連番をリネーム削除。
		・
----------------------------------------------------------------------------------
=end comment


binmode STDOUT, ':encoding(UTF-8)';

my $base_dir = '04_assemble';

opendir(my $dh, $base_dir) or die "Cannot open directory $base_dir: $!";
my @folders = grep { /^fukushu\d+$/ && -d "$base_dir/$_" } readdir($dh);
closedir($dh);

foreach my $folder (@folders) {
    if ($folder =~ /^fukushu(\d{2})$/) {
        my $num = $1;
        my $target_dir = "$base_dir/$folder/front_end";

        # front_end フォルダがなければ作成
        unless (-d $target_dir) {
            make_path($target_dir) or die "Failed to create $target_dir: $!";
            print "Created directory: $target_dir\n";
        }

        my $cover_src    = "$base_dir/cover_$num.jpg";
        my $colophon_src = "$base_dir/colophon_$num.jpg";
        my $cover_dst    = "$target_dir/cover_$num.jpg";
        my $colophon_dst = "$target_dir/colophon_$num.jpg";

        # cover
        if (-f $cover_src) {
            copy($cover_src, $cover_dst) or warn "Failed to copy $cover_src: $!";
            print "Copied: $cover_src -> $cover_dst\n";
        } else {
            warn "Missing file: $cover_src\n";
        }

        # colophon
        if (-f $colophon_src) {
            copy($colophon_src, $colophon_dst) or warn "Failed to copy $colophon_src: $!";
            print "Copied: $colophon_src -> $colophon_dst\n";
        } else {
            warn "Missing file: $colophon_src\n";
        }
    }
}
