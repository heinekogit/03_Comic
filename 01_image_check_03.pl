#!/usr/local/bin/perl

use strict;
use warnings;

use utf8;
binmode STDIN, 'encoding(cp932)';
binmode STDOUT, 'encoding(cp932)';
binmode STDERR, 'encoding(cp932)';
use Encode;

use Image::Size 'imgsize';
use Image::ExifTool;

# ログ用配列
my @log;
my @missing_numbers;  # 連番のヌケを記録
my @wrong_extensions; # 不正な拡張子を記録

# チェック対象の画像ファイルを取得
my @image_files = glob("02_image_work/0210_inspect_box/*/*");

# ログ出力用ファイル
open(my $log_fh, ">:encoding(UTF-8)", "02_image_work/0210_inspect_box/inspect_log.txt") or die "ログファイルを開けません: $!";

# チェック用変数
my $expected_number = 1;  # 連番の期待値
my ($base_width, $base_height);

# 画像ファイルのチェック
foreach my $file (sort @image_files) {
    # ファイル名だけを取得
    my ($filename) = $file =~ /([^\\\/]+)$/;

    # 拡張子をチェック
    unless ($filename =~ /\.jpg$/i) {
        if ($filename =~ /\.(png|tiff|gif|jpeg)$/i) {
            push @wrong_extensions, $filename;
        }
        next; # 拡張子が .jpg 以外の場合は連番チェックをスキップ
    }

    # ファイル名から連番を抽出
    my ($number) = $filename =~ /i-(\d+)\.jpg$/;

    # 連番のヌケをチェック
    if (defined $number) {
        while ($number > $expected_number) {
            push @missing_numbers, sprintf("i-%03d.jpg\n", $expected_number);
            $expected_number++;
        }
        $expected_number++;
    }

    # 画像サイズを取得
    my ($width, $height, $dpi_x, $dpi_y) = imgsize($file);

    # 解像度情報が取得できない場合は ExifTool を使用
    if (!defined $dpi_x || !defined $dpi_y || $dpi_x == 0 || $dpi_y == 0) {
        my $exif = Image::ExifTool->new;
        $exif->ExtractInfo($file);
        $dpi_x = $exif->GetValue('XResolution') || 0;
        $dpi_y = $exif->GetValue('YResolution') || 0;

        # 解像度が取得できない場合のデフォルト値
        if ($dpi_x == 0 || $dpi_y == 0) {
            $dpi_x = 72; # デフォルト値
            $dpi_y = 72; # デフォルト値
        }
    }

    if (!defined $width || !defined $height) {
        push @log, "画像サイズを取得できません: $filename\n";
        next;
    }

    # 基準サイズを設定（最初の画像を基準とする）
    if (!defined $base_width || !defined $base_height) {
        $base_width = $width;
        $base_height = $height;
    }

    # サイズが異なる場合を指摘
    my $size_warning = "";
    if ($width != $base_width || $height != $base_height) {
        $size_warning = sprintf("（サイズが異なります: 基準 %dx%d）", $base_width, $base_height);
    }

    # 解像度情報がない場合の処理
    my $dpi_warning = "";
    if ($dpi_x == 0 || $dpi_y == 0) {
        $dpi_warning = "（解像度情報がありません）";
    }

    # ログに記録
    push @log, sprintf(
        "%s　幅：%dpx　高：%dpx　解像度：%dx%ddpi %s %s\n",
        $filename, $width, $height, $dpi_x, $dpi_y, $size_warning, $dpi_warning
    );
}

# ログをターミナルに表示
#   print "\nチェック結果:\n";
#   print @log;

# 拡張子のチェック結果を記録
if (@wrong_extensions) {
    print $log_fh "\n不正な拡張子のファイル:\n";
    print $log_fh join("", map { "$_\n" } @wrong_extensions);
} else {
    print $log_fh "\n不正な拡張子のファイルはありません。\n";
}

# 連番のヌケを記録
if (@missing_numbers) {
    print $log_fh "\n連番のヌケ:\n";
    print $log_fh join("", @missing_numbers);
} else {
    print $log_fh "\n連番のヌケはありません。\n";
}

# ログをファイルに出力
   print $log_fh "\n画像チェック結果:\n";
   print $log_fh @log;

close($log_fh);

print "\nログファイルに出力しました: 02_image_work/0210_inspect_box/inspect_log.txt\n";


