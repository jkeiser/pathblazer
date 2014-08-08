require 'support/spec_support'
require 'pathblazer/path_set/formats/bash'

describe Pathblazer::PathSet::Formats::Bash do

  let :bash do
    PathSet::Formats::Bash.new
  end

  Path = PathSet::PathExpression
  Char = PathSet::CharExpression

  context 'basic tokens' do
    TESTS = {
      'a' => 'a',
      'abc' => 'abc',
      '' => [],
      '*' => Char::STAR,
      '\\\\\\a\\/' => '\\a/',
      'a/b' => [ 'a', 'b' ],
      'a/b/c' => [ 'a', 'b', 'c' ],
      'abc/*/def' => Path::Sequence.new([ 'abc', Char::STAR, 'def' ])
    }
    TAGS = {
#      'abc/*/def' => [:focus]
    }

    TESTS.each do |input, expected|
      it "should parse #{input.inspect} as #{expected.inspect}", *(TAGS[input] || []) do
        expect(bash.from(input).expression).to eq expected
      end
    end

    # ''
    # abc
    # *
    # unicode char
    # \\\a\/
    # []
    # a/b
    # /
    # ///
    # a///b
    # {a,b}
    # **
    # a**.txt
    # a/**/*
  end
end
