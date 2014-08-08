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
      '**' => Path::GLOBSTAR,
      '\\\\\\a\\/' => '\\a/',
      'a/b' => [ 'a', 'b' ],
      '{a,b,c}' => Char::Union.new([ 'a', 'b', 'c']),
      '?' => Char::ANY,

      '{}' => [],
      '{,}' => Char::Union.new([ '', '' ]),
      '{a,*,b*c,d}' => Char::Union.new([ 'a', Char::STAR, Char::Sequence.new([ 'b', Char::STAR, 'c']), 'd' ]),
      '{a,b/*/c,d}' => Char::Union.new([ 'a', Path::Sequence.new([ 'b', Char::STAR, 'c' ]), 'd']),
      'a{b,c}d' => Char::Sequence.new([ 'a', Char::Union.new([ 'b', 'c' ]), 'd']),
      'a{}b' => 'ab',
      'a{/}b' => [ 'a', 'b' ],
      'a/{b}/c' => [ 'a', 'b', 'c' ],

      'a/b/c' => [ 'a', 'b', 'c' ],
      'abc/*/def' => Path::Sequence.new([ 'abc', Char::STAR, 'def' ]),
      'a/b*c/d' => Path::Sequence.new([ 'a', Char::Sequence.new([ 'b', Char::STAR, 'c' ]), 'd']),
      'a/b/c/d/e/f/g' => %w(a b c d e f g),

      '/' => [ '', '' ],
      '///' => [ '', '', '', '' ],
      'a//b' => [ 'a', '', 'b' ],

      'a**b' => Char::Sequence.new([ 'a', Path::GLOBSTAR, 'b' ]),
      'a/**/b' => Path::Sequence.new([ 'a', Path::GLOBSTAR, 'b' ]),
      'a/b**c/d' => Path::Sequence.new([ 'a', Char::Sequence.new([ 'b', Path::GLOBSTAR, 'c' ]), 'd' ]),
    }
    TAGS = {
#      'a/b*c/d' => [:focus]
    }

    TESTS.each do |input, expected|
      it "should parse #{input.inspect} as #{expected}", *(TAGS[input] || []) do
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

  context 'concat with empties' do
    # Bash parser doesn't support empty paths, so we have to test that directly.
    it 'Path.concat('', '') should yield [ '', '' ]' do
      expect(Char.concat('', '')).to eq ''
      expect(Char.concat([], '')).to eq ''
      expect(Path.concat('', '')).to eq [ '', '' ]
      expect(Char.concat([ '', '' ], '')).to eq [ '', '' ]
    end

    it '' do
      expect(Char.concat('', [])).to eq ''
      expect(Char.concat([], '')).to eq ''
      expect(Char.concat([], [])).to eq ''
      expect(Char.concat('', '')).to eq ''
      expect(Char.concat('', Path.concat('', ''))).to eq [ '', '' ]
      expect(Char.concat(Path.concat('', ''), '')).to eq [ '', '' ]
    end
  end
end
