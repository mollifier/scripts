#!/usr/bin/env ruby

ARGF.each_line(rs = nil) do |buf|
  printf "javascript:%s\n",
    buf.gsub(/\s+$/, "").
    gsub("%", "%25").
    gsub("\n", "%0A").gsub("\t", "%09")
end

