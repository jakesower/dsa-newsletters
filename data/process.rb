#!/usr/bin/ruby

# The script will output JSON representing all articles from the source
# newsletters. It will be written to stdout by default.

require 'fileutils'
require 'date'
require 'json'

# Note: pandoc is required to use this script. See: http://pandoc.org

MONTHS = Date::MONTHNAMES.compact

CONFIG = {
  src_dir: './docx',
  md_dir: './md',
  charmap: {
    '“' => '"',
    '”' => '"',
    '‘' => "'",
    '’' => "'",
    '–' => '–',
    '…' => '...',
    ' ' => '',  # weird artifact characters
    /!\[\]\(media[^}]+}/ => '',

    # pandoc artifacts
    '\\$' => '$',
    /\\$/ => '',
    /\^([a-z]+)\^/i => '<sup>\1</sup>'

  },
  patterns: {
    id: /^[* ]*The Washington Socialist[* ]*&lt;&gt; (#{MONTHS.join('|')}|Midsummer|Summer|Labor Day) \d{4}[* ]*$/,
    byline: /^[* ]*By [A-Z. ]+[* ]*$/i,
    date: /^(#{Date::DAYNAMES.join('|')}), (#{MONTHS.join('|')}) [0-9stndrh]+, \d{4}$/,
    empty: /^$/,
    editor: /^[* ]*Editor: [A-Z. ]+[* ]*$/i
  },
  extractors: {
    byline: ->(l) { l.match(/By ([A-Z. ]+)/i).captures[0] },
    date: ->(l) { Date.parse( l ) },
    editor: ->(l) { l.match(/Editor: ([A-Z. ]+)/i).captures[0] },
    generic: ->(l) { l },
    title: -> (l) { l.match(/^[\[*]*([^\]*]+)/).captures[0] }
  },
  sections: {
    intro: [:date, :generic],
    article: [:generic, :date, :id],
    alt_article: [:generic, :id],
    no_id: [:generic, :date],  # used for Sep-Nov 2012
    alt_no_id: [:generic, :byline]
  }
}

# General outline of a WS Edition:
# - Title, Attribution Chrome
# - Introduction
# - Events
# - TOC
# - Article 1, Article 2, ...

# Desired output: All articles, including introduction, with following info:
# - Title
# - Author (assumed to be editor in case of introduction)
# - Date
# - Formatted body (using markdown)

# Parsing functions

# Line analysis path

extract_line = ->( line, type = line[:type] ) do
  CONFIG[:extractors][type].call( line[:line] )
end

analyze_lines = ->( corpus ) do
  lines = corpus.
    split("\n").
    map(&:strip).
    map do |line|
      hit = CONFIG[:patterns].find{|(k,v)| line =~ v}
      {
        line: line,
        type: hit ? hit[0] : :generic
      }
    end
end


pattern_indices = ->( lines, pattern ) do
  (0..( lines.length - 1 )).to_a.
    select { |idx|
      nonempty = lines[idx..-1].reject{|l| l[:type] == :empty}
      cands = nonempty[0..(pattern.length - 1)]
      lines[idx][:type] != :empty && cands.map{|g| g[:type]} == pattern
    }
end


format_body_lines = ->( lines ) do
  lines.map{|l| l[:line]}.join("\n").strip
end


# folds sequences of generic lines into single generic lines
compress_generics = ->( lines ) do
  r = ->( a ) { a.empty? ? [] : [{ type: :generic, line: a.join(' ') }]}
  x = lines.reduce({ result: [], accum: []}) do |memo, line|
    line[:type] == :generic ?
      { result: memo[:result], accum: memo[:accum] << line[:line] } :
      { result: memo[:result].concat(r.(memo[:accum])) << line, accum: [] }
  end

  x[:result].concat(r.(x[:accum]))
end


article_indices = ->( lines, no_id = false ) do
  patterns = no_id ? [:no_id, :alt_no_id] : [:article, :alt_article]
  patterns.reduce([]) do |memo,type|
    memo + pattern_indices.( lines, CONFIG[:sections][type] )
  end.sort
end


get_introduction = ->( lines ) do
  author = extract_line.( lines.find{|l| l[:type] == :editor} )
  issue_line = lines.find{|l| l[:line] =~ /\*\*Articles from( the)? /}
  issue = issue_line[:line].match(/from( the)? (.*) Issue/).captures[1]
  # puts article_indices.(lines).inspect

  intro_start = pattern_indices.( lines, CONFIG[:sections][:intro] ).first
  intro_end = article_indices.(lines).first - 1

  return nil if !intro_start || intro_end <= intro_start

  {
    title: "The Washington Socialist—#{issue} Issue",
    author: author,
    issue: issue,
    order: -1,
    date: extract_line.( lines[intro_start] ),
    body: format_body_lines.( lines[(intro_start + 1)..intro_end] )
  }
end


get_articles = ->( lines, no_id = false ) do
  idxs = article_indices.( lines, no_id )
  pairs = idxs.each_with_index.map{|x,idx| [x, idxs[idx+1] ? idxs[idx+1]-1 : -1]}
  default_date = extract_line.(lines.find{|l| l[:type] == :date})
  issue_line = lines.find{|l| l[:line] =~ /\*\*Articles from( the)? /}
  issue = issue_line[:line].match(/from( the)? (.*) Issue/).captures[1]

  pairs.each_with_index.map do |p,idx|
    ls = lines[p[0]..p[1]]
    body_start = (1..(ls.length - 1)).to_a.find{|i| ls[i][:type] == :generic}
    byline = ls.find{|l| l[:type] == :byline}
    date = ls.find{|l| l[:type] == :date}
    # puts ({
    #   date: date,
    #   byline: byline,
    #   title: ls[0],
    #   body_start: body_start
    # }).inspect

    {
      title: extract_line.(ls[0], :title),
      date: date ? extract_line.(date) : default_date,
      issue: issue,
      author: byline ? extract_line.(byline) : '',
      body: format_body_lines.( ls[ body_start..-1 ]),
      order: idx
    }
  end
end


def recode_windows_1252_to_utf8(string)
  string.gsub(/[\u0080-\u009F]/) {|x| x.getbyte(1).chr.
    force_encoding('windows-1252').encode('utf-8') }
end

# Convert documents to markdown
FileUtils.mkdir_p( CONFIG[:md_dir] )
Dir.new( CONFIG[:src_dir] ).select{|f| !File.directory?( f )}.each do |f|
  # `pandoc "#{CONFIG[:src_dir]}/#{f}" -o "#{CONFIG[:md_dir]}/#{f.split('.').first}.md"`
end

# Begin extracting articles from the md files
files = Dir.new( CONFIG[:md_dir] ).select{|f| !File.directory?( f )}
no_ids = [ 'The Washington Socialist-November 2012.md', 'The Washington Socialist-October 2012.md', 'The Washington Socialist-September 2012.md' ]

out = files.flat_map do |f|
  no_id = no_ids.include?( f )
  raw_corpus = File.read( "#{CONFIG[:md_dir]}/#{f}" )
  raw_corpus = recode_windows_1252_to_utf8( raw_corpus )

  # puts raw_corpus
  # exit 0
  corpus = CONFIG[:charmap].reduce( raw_corpus ) do |memo, (s,r)|
    memo.gsub( s, r )
  end

  lines = analyze_lines.(corpus)
  lines = compress_generics.(lines)

  intro = no_id ? nil : get_introduction.(lines)
  intro ? get_articles.(lines) << get_introduction.(lines) : get_articles.(lines, no_id)
end

puts JSON.generate( out );
