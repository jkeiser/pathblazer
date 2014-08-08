require 'support/spec_support'
require 'pathblazer/path_set/formats/bash'

describe Pathblazer::PathSet::Formats::Bash do

  let :bash do
    PathSet::Formats::Bash.new
  end

  context 'basic tokens' do
    TESTS = {
      'a' => 'a',
      'abc' => 'abc',
      '' => [],
      '*' => PathSet::CharExpression::STAR,
      '\\\\\\a\\/' => '\\a/',
      'a/b' => [ 'a', 'b' ],
#      'abc/*/def' => PathSet::PathExpression::Sequence.new([ 'abc', PathSet::CharExpression::STAR, 'def' ])
    }
    TAGS = {
#      'a/b' => [:focus]
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
