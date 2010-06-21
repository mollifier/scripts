#!/usr/bin/env ruby

ARGF.each_line(rs = nil) do |buf|
  puts buf.sub(/^javascript:/, "").
    gsub("%0A", "\n").gsub("%09", "\t").
    gsub("%20", " ").gsub("%25", "%")
end

