use strict;
use warnings;
use utf8;

use File::Find;
use File::Spec;
use File::Basename qw(basename dirname);
use File::Path qw(make_path);
use File::Copy qw(copy);
use Getopt::Long qw(GetOptions);
use Cwd qw(abs_path getcwd);

binmode STDOUT, ':encoding(cp932)';
binmode STDERR, ':encoding(cp932)';

my $root;
my $xhtml_dir;
my $css_dir;
my $dry_run = 0;
my $help    = 0;

# v3: 自動 safelist。--no-safelist で無効化。--safelist は従来通り追加読込可
my $no_safelist = 0;
my @safelist_files_cli;

GetOptions(
    'root=s'        => \$root,
    'xhtml-dir=s'   => \$xhtml_dir,
    'css-dir=s'     => \$css_dir,
    'dry-run'       => \$dry_run,
    'safelist=s@'   => \@safelist_files_cli,  # 追加ロード（任意）
    'no-safelist'   => \$no_safelist,         # 自動読込を無効化
    'help'          => \$help,
) or usage();

usage() if $help;
if (!defined $root && !defined $xhtml_dir && !defined $css_dir) {
    $root = '05_output';
}

my @targets = determine_targets($root, $xhtml_dir, $css_dir);

# ===== safelist 読込 =====
my ($SAFE_CLASS, $SAFE_ID) = ({}, {});
unless ($no_safelist) {
    my @auto = find_default_safelists($root);
    my @all  = (@auto, @safelist_files_cli);
    ($SAFE_CLASS, $SAFE_ID) = load_safelist(@all);
    my $cnt_c = scalar keys %$SAFE_CLASS;
    my $cnt_i = scalar keys %$SAFE_ID;
    print "[safelist] loaded files: ", (join(', ', @auto, @safelist_files_cli) || '(none)'), "\n";
    print "[safelist] classes=$cnt_c, ids=$cnt_i\n";
} else {
    print "[safelist] auto-load disabled (--no-safelist)\n";
    ($SAFE_CLASS, $SAFE_ID) = ({}, {});
}

my $overall_removed = 0;

for my $target (@targets) {
    my %used_class;
    my %used_id;

    # XHTMLスキャン
    find(
        {
            wanted => sub {
                return unless -f $File::Find::name;
                return unless $File::Find::name =~ /\.(?:xhtml|html|htm)$/i;
                my $content = slurp($File::Find::name);
                extract_classes($content, \%used_class);
                extract_ids($content,     \%used_id);
            },
            no_chdir => 1,
        },
        $target->{xhtml_dir}
    );

    # CSS一覧
    my @css_files = glob(File::Spec->catfile($target->{css_dir}, '*.css'));
    if (!@css_files) {
        warn "no CSS files found in $target->{css_dir}\n";
        next;
    }

    # バックアップ
    my $backup_dir;
    if (!$dry_run) {
        $backup_dir = backup_css($target);
        print "Backed up original CSS to $backup_dir\n" if defined $backup_dir;
    }

    for my $css_file (sort @css_files) {
        my ($removed, $kept) = process_css_file(
            $css_file,
            \%used_class,
            \%used_id,
            $SAFE_CLASS,
            $SAFE_ID,
            $dry_run
        );
        $overall_removed += $removed;

        printf "%s: kept %d rules, removed %d rules%s\n",
            $css_file, $kept, $removed, ($dry_run ? " (dry-run)" : "");
    }
}

print "TOTAL removed rules: $overall_removed\n";

# ------------------------------
# ターゲット解決
# ------------------------------
sub determine_targets {
    my ($root, $xhtml_dir, $css_dir) = @_;
    my @targets;

    if (defined $root) {
        my $abs_root = File::Spec->rel2abs($root);
        die "root directory not found: $abs_root\n" unless -d $abs_root;

        if (defined $xhtml_dir || defined $css_dir) {
            $xhtml_dir ||= File::Spec->catdir($abs_root, 'item', 'xhtml');
            $css_dir   ||= File::Spec->catdir($abs_root, 'item', 'style');
            push @targets, build_target($abs_root, $xhtml_dir, $css_dir);
        } else {
            push @targets, collect_direct_targets($abs_root);
        }
    } else {
        push @targets, build_target(undef, $xhtml_dir, $css_dir);
    }

    return @targets;
}

sub collect_direct_targets {
    my ($abs_root) = @_;
    my @targets;
    opendir my $dh, $abs_root or die "can't opendir $abs_root: $!\n";
    while (my $entry = readdir $dh) {
        next if $entry eq '.' || $entry eq '..';
        my $candidate = File::Spec->catdir($abs_root, $entry);
        next unless -d $candidate;
        my $xhtml_dir = File::Spec->catdir($candidate, 'item', 'xhtml');
        my $css_dir   = File::Spec->catdir($candidate, 'item', 'style');
        next unless -d $xhtml_dir && -d $css_dir;
        push @targets, build_target($candidate, $xhtml_dir, $css_dir);
    }
    closedir $dh;
    return @targets;
}

sub build_target {
    my ($root, $xhtml_dir, $css_dir) = @_;
    my $abs_xhtml = File::Spec->rel2abs($xhtml_dir);
    my $abs_css   = File::Spec->rel2abs($css_dir);
    my $abs_root  = defined $root ? File::Spec->rel2abs($root) : undef;

    die "xhtml directory not found: $abs_xhtml\n" unless -d $abs_xhtml;
    die "css directory not found: $abs_css\n"     unless -d $abs_css;

    return {
        root      => $abs_root,
        xhtml_dir => $abs_xhtml,
        css_dir   => $abs_css,
    };
}

# ------------------------------
# safelist 自動検出
# ------------------------------
sub find_default_safelists {
    my ($root_arg) = @_;
    my @candidates;

    my $script_path = abs_path($0);
    my $script_dir  = dirname($script_path);
    my $cwd         = getcwd();

    # 1) スクリプトと同じフォルダ
    push @candidates, File::Spec->catfile($script_dir, 'safelist_default.txt');
    my $script_sl = File::Spec->catdir($script_dir, 'safelist');
    if (-d $script_sl) {
        push @candidates, glob(File::Spec->catfile($script_sl, '*.txt'));
    }

    # 2) カレント
    push @candidates, File::Spec->catfile($cwd, 'safelist_default.txt');

    # 3) --root/_config
    if (defined $root_arg) {
        my $abs_root = File::Spec->rel2abs($root_arg);
        my $cfg_dir  = File::Spec->catdir($abs_root, '_config');
        if (-d $cfg_dir) {
            push @candidates, glob(File::Spec->catfile($cfg_dir, 'safelist*.txt'));
        }
    }

    # 実在のみ返す
    my %seen;
    my @found;
    for my $p (@candidates) {
        next unless defined $p && -f $p;
        next if $seen{$p}++;
        push @found, $p;
    }
    return @found;
}

# ------------------------------
# safelist 読み込み
# ------------------------------
sub load_safelist {
    my (@files) = @_;
    my (%safe_class, %safe_id);
    for my $f (@files) {
        next unless defined $f && -f $f;
        open my $fh, '<:encoding(UTF-8)', $f or next;
        while (my $line = <$fh>) {
            $line =~ s/\r?\n\z//;
            $line =~ s/^\s+|\s+\z//g;
            next if $line eq '' || $line =~ /^#/;
            if ($line =~ /^\.(.+)$/) {
                $safe_class{$1} = 1;
            } elsif ($line =~ /^#(.+)$/) {
                $safe_id{$1} = 1;
            } else {
                $safe_class{$line} = 1;  # ドット/ハッシュ無しは class
            }
        }
        close $fh;
    }
    return (\%safe_class, \%safe_id);
}

# ------------------------------
# XHTML → used tokens
# ------------------------------
sub slurp {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path or die "can't open $path: $!\n";
    local $/;
    my $s = <$fh>;
    close $fh;
    return $s;
}

sub extract_classes {
    my ($content, $seen) = @_;
    while ($content =~ /class\s*=\s*"([^"]*)"/gsi) {
        my $value = $1;
        $value =~ tr/\r\n\t/   /;
        for my $class (split /\s+/, $value) {
            next unless length $class;
            $seen->{$class} = 1;
        }
    }
    while ($content =~ /class\s*=\s*'([^']*)'/gsi) {
        my $value = $1;
        $value =~ tr/\r\n\t/   /;
        for my $class (split /\s+/, $value) {
            next unless length $class;
            $seen->{$class} = 1;
        }
    }
}

sub extract_ids {
    my ($content, $seen) = @_;
    while ($content =~ /id\s*=\s*"([^"]*)"/gsi) {
        my $value = $1;
        $value =~ tr/\r\n\t/   /;
        next unless length $value;
        $seen->{$value} = 1;
    }
    while ($content =~ /id\s*=\s*'([^']*)'/gsi) {
        my $value = $1;
        $value =~ tr/\r\n\t/   /;
        next unless length $value;
        $seen->{$value} = 1;
    }
}

# ------------------------------
# CSS バックアップ
# ------------------------------
sub backup_css {
    my ($target) = @_;
    return unless defined $target->{root};

    my $title_root = $target->{root};
    my $parent_dir = dirname($title_root);
    my $title_name = basename($title_root);

    my $bkroot = File::Spec->catdir($parent_dir, '_backup_style');
    my $bkdir  = File::Spec->catdir($bkroot, $title_name . '_style_original');

    make_path($bkroot) unless -d $bkroot;
    make_path($bkdir)  unless -d $bkdir;

    my @css = glob(File::Spec->catfile($target->{css_dir}, '*.css'));
    for my $f (@css) {
        my $dst = File::Spec->catfile($bkdir, basename($f));
        copy($f, $dst) or warn "backup copy failed $f -> $dst: $!\n";
    }
    return $bkdir;
}
sub process_css_file {
    my ($path, $used_class, $used_id, $safe_class, $safe_id, $dry_run) = @_;
    my $css = slurp($path);

    my ($output, $removed, $kept) = parse_css_block(
        $css, 0, length($css),
        $used_class, $used_id, $safe_class, $safe_id
    );

    if (!$dry_run) {
        open my $wf, '>:encoding(UTF-8)', $path or die "can't write $path: $!\n";
        print {$wf} $output;
        close $wf;
    }
    return ($removed, $kept);
}

# ------------------------------
# CSS 字句：トップレベル/ブロックを再帰的に処理
# ------------------------------
sub parse_css_block {
    my ($css, $start_pos, $end_pos, $used_class, $used_id, $safe_class, $safe_id) = @_;

    my $pos     = $start_pos;
    my $output  = '';
    my $removed = 0;
    my $kept    = 0;

    while ($pos < $end_pos) {
        # コメント
        if (substr($css, $pos) =~ /\G\/\*.*?\*\//gcs) {
            my $m = $&;
            $output .= $m;
            $pos   += length($m);
            next;
        }

        # 空白
        if (substr($css, $pos) =~ /\G\s+/gcs) {
            my $m = $&;
            $output .= $m;
            $pos   += length($m);
            next;
        }

        # @rule?
        if (substr($css, $pos) =~ /\G\@([a-zA-Z0-9_-]+)/gcs) {
            my $matched = $&;
            my $at_name = $1;
            my $at_head = '@' . $at_name;
            $pos += length($matched);

            my $prelude = '';
            while ($pos < $end_pos) {
                my $ch = substr($css, $pos, 1);
                last if $ch eq '{' || $ch eq ';';
                $prelude .= $ch;
                $pos++;
            }

            if ($pos < $end_pos && substr($css, $pos, 1) eq ';') {
                $output .= $at_head . $prelude . ';';
                $pos++;
                $kept++;
                next;
            }

            if ($pos < $end_pos && substr($css, $pos, 1) eq '{') {
                $output .= $at_head . $prelude . '{';
                $pos++;
                my ($inner, $inner_removed, $inner_kept, $new_pos) =
                    parse_braced_block($css, $pos, $end_pos, $used_class, $used_id, $safe_class, $safe_id);
                $output  .= $inner;
                $removed += $inner_removed;
                $kept    += $inner_kept;
                $pos      = $new_pos;
                next;
            }

            $output .= $at_head . $prelude;
            next;
        }

        # 通常ルール（Selectors { ... }）
        if (substr($css, $pos) =~ /\G([^\{]+)\{([^\{\}]*?)\}/gcs) {
            my $match = $&;
            my ($selectors, $body) = ($1, $2);
            my $pruned = prune_selector_list($selectors, $used_class, $used_id, $safe_class, $safe_id);

            $pos += length($match);

            if ($pruned eq '') {
                $removed++;
            } else {
                $output .= $pruned . '{' . $body . '}';
                $kept++;
            }
            next;
        }

        # 1文字ずつ消費（保険策）
        $output .= substr($css, $pos, 1);
        $pos++;
    }

    return ($output, $removed, $kept);
}
sub parse_braced_block {
    my ($css, $pos, $end_pos, $used_class, $used_id, $safe_class, $safe_id) = @_;

    my $depth   = 1;
    my $output  = '';
    my $removed = 0;
    my $kept    = 0;

    while ($pos < $end_pos && $depth > 0) {
        # コメント
        if (substr($css, $pos) =~ /\G\/\*.*?\*\//gcs) {
            my $m = $&;
            $output .= $m;
            $pos   += length($m);
            next;
        }

        # 空白
        if (substr($css, $pos) =~ /\G\s+/gcs) {
            my $m = $&;
            $output .= $m;
            $pos   += length($m);
            next;
        }

        # @rule
        if (substr($css, $pos) =~ /\G\@([a-zA-Z0-9_-]+)/gcs) {
            my $matched = $&;
            my $at_name = $1;
            my $at_head = '@' . $at_name;
            $pos += length($matched);

            my $prelude = '';
            while ($pos < $end_pos) {
                my $ch = substr($css, $pos, 1);
                last if $ch eq '{' || $ch eq ';';
                $prelude .= $ch;
                $pos++;
            }
            if ($pos < $end_pos && substr($css, $pos, 1) eq ';') {
                $output .= $at_head . $prelude . ';';
                $pos++;
                $kept++;
                next;
            }
            if ($pos < $end_pos && substr($css, $pos, 1) eq '{') {
                $output .= $at_head . $prelude . '{';
                $pos++;
                my ($inner, $inner_removed, $inner_kept, $new_pos) =
                    parse_braced_block($css, $pos, $end_pos, $used_class, $used_id, $safe_class, $safe_id);
                $output  .= $inner;
                $removed += $inner_removed;
                $kept    += $inner_kept;
                $pos      = $new_pos;
                next;
            }
            $output .= $at_head . $prelude;
            next;
        }

        # 通常ルール
        if (substr($css, $pos) =~ /\G([^\{]+)\{([^\{\}]*?)\}/gcs) {
            my $match = $&;
            my ($selectors, $body) = ($1, $2);
            my $pruned = prune_selector_list($selectors, $used_class, $used_id, $safe_class, $safe_id);

            $pos += length($match);

            if ($pruned eq '') {
                $removed++;
            } else {
                $output .= $pruned . '{' . $body . '}';
                $kept++;
            }
            next;
        }

        my $ch = substr($css, $pos, 1);
        if    ($ch eq '{') { $output .= $ch; $depth++; }
        elsif ($ch eq '}') { $output .= $ch; $depth--; }
        else               { $output .= $ch; }
        $pos++;
    }

    return ($output, $removed, $kept, $pos);
}
sub prune_selector_list {
    my ($selectors, $used_class, $used_id, $safe_class, $safe_id) = @_;

    my $s = $selectors;
    $s =~ s/\/\*.*?\*\///gs;      # コメント除去
    $s =~ s/\s+/ /g;

    my @parts = split /\s*,\s*/, $s;
    my @kept;

    PART: for my $sel (@parts) {
        my $check = $sel;

        # 擬似要素/クラスを除去（:hover, ::before, :nth-child(...)など）
        $check =~ s/::?[a-zA-Z0-9_-]+(?:\([^)]*\))?//g;

        # 属性セレクタが含まれる場合は安全のため keep
        if ($check =~ /\[/) {
            push @kept, $sel;
            next PART;
        }

        # トークン抽出
        my @classes = ($check =~ /\.(-?[_a-zA-Z]+[_a-zA-Z0-9-]*)/g);
        my @ids     = ($check =~ /#(-?[_a-zA-Z]+[_a-zA-Z0-9-]*)/g);

        # トークン無し（タグ名のみ等）は keep（誤削除回避）
        if (!@classes && !@ids) {
            push @kept, $sel;
            next PART;
        }

        # safelist が1つでもヒットしたら keep
        for my $c (@classes) { if ($safe_class->{$c}) { push @kept, $sel; next PART; } }
        for my $i (@ids)     { if ($safe_id->{$i})   { push @kept, $sel; next PART; } }

        # 使用判定（どれか1つでも使われていれば keep）
        for my $c (@classes) { if ($used_class->{$c}) { push @kept, $sel; next PART; } }
        for my $i (@ids)     { if ($used_id->{$i})   { push @kept, $sel; next PART; } }

        # ここに来たら未使用 → 捨てる
    }

    my $joined = join(', ', @kept);
    $joined =~ s/\s+,/, /g;
    return $joined;
}

# ------------------------------
# ヘルプ
# ------------------------------
sub usage {
    my ($msg) = @_;
    warn "$msg\n" if defined $msg;
    die <<'HELP';
Usage: perl 05_clean_unused_css_v3.pl [options]
    --root=PATH        Root directory (default: 05_output). Direct child folders are treated as titles.
    --xhtml-dir=PATH   Explicit path to an XHTML directory
    --css-dir=PATH     Explicit path to a CSS directory
    --no-safelist      Disable auto-loading of safelist files
    --safelist=FILE    Additional safelist file (.class / #id per line). Can be repeated.
    --dry-run          Show what would be removed without writing files
    --help             Show this help

Auto safelist lookup (merged in this order if present):
  [script dir]/safelist_default.txt
  [script dir]/safelist/*.txt
  [cwd]/safelist_default.txt
  [--root]/_config/safelist*.txt
HELP
}





