#!/usr/bin/ruby1.9.1
# -*- encoding: utf-8 -*-

AVAST_REPORT_FILE = ENV['HOME'] + "/.avast/report.txt"

File.open(AVAST_REPORT_FILE, "r:shift_jis:utf-8"){|f|
  # パラグラフモードで読み込む
  f.each_line(rs = "") do |line|
    # 感染ファイル数が0でない場合、出力する
    if /^#\sinfected\sfiles:\s+0*[1-9]/ =~ line
      puts line
    end
  end
}

