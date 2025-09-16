

# サブルーチン　文字変換    ===========================================================================

sub umekomi {

    $aki = "　";  # 初期値として全角スペース

    s/●タイトル名●/$koumoku_content[0]/g;  # タイトル名を置換

    # 共通の処理をサブルーチン化
    if ($koumoku_content[65] eq '有' || $koumoku_content[65] eq '') {
        $aki = "" if $koumoku_content[65] eq '';  # 空の場合、$akiをリセット

        my $notate = $aki;

        # 66と67がブランクでない場合、それらを処理
        if ($koumoku_content[66] ne '' || $koumoku_content[67] ne '') {
            chomp($koumoku_content[66], $koumoku_content[67]);  # 改行削除
            $notate .= $koumoku_content[66] if $koumoku_content[66] ne '';  # 66があれば追加
            $notate .= $koumoku_content[1];  # 必ず話数字を追加
            $notate .= $koumoku_content[67] if $koumoku_content[67] ne '';  # 67があれば追加
        } else {
            # すべてブランクの場合は話数字のみ
            $notate .= $koumoku_content[1];
        }

        $notate =~ s/\R//g;  # 全体から改行削除
        s/●話巻順番●/$notate/g;  # プレースホルダ置換
    }


    # 他の置換
    s/●タイトル名カタカナ●/$koumoku_content[5]/g;  # 2L以上は使わない
    s/●話数3桁●/$koumoku_content[2]/g;  # 2L以上は使わない
    s/●出版社名●/$koumoku_content[12]/g;  # 2L以上は使わない
    s/●出版社名カタカナ●/$koumoku_content[15]/g;  # 2L以上は使わない

}



