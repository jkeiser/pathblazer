require 'support/spec_support'
require 'pathblazer/path_set/formats/bash'

describe Pathblazer::PathSet::Formats::Bash do

  let :bash do
    PathSet::Formats::Bash.new
  end

  Path = PathSet::PathExpression
  Char = PathSet::CharExpression
  Charset = PathSet::Charset

  context 'basic tokens' do
    TESTS = {
      'a'             => 'a',
      'abc'           => 'abc',
      ''              => [],
      '*'             => Char::STAR,
      '**'            => Path::GLOBSTAR,
      '\\\\\\a\\/b'   => '\\a/b',
      'a/b'           => [ 'a', 'b' ],
      '{a,b,c}'       => Char::Union.new([ 'a', 'b', 'c']),
      '?'             => Char::ANY,
      '^-]},'         => '^-]},',

      '[a]'           => 'a',
      '[a-z]'         => Charset.new('a-z'),
      '[A-Za-z]'      => Charset.new('A-Z', 'a-z'),
      '[a-zA-Z]'      => Charset.new('A-Z', 'a-z'),
      '[A-Z0]'        => Charset.new('A-Z', '0'),
      '[0A-Z]'        => Charset.new('A-Z', '0'),
      '[A-Z02-9]'     => Charset.new('A-Z', '0', '2-9'),
      '[a\-z\]c]'     => Charset.new('a', '-', 'z', ']', 'c'),
      '[^B]'          => Charset.new([0, 'A'], ['C', Charset::UNICODE_MAX]),
      '[^B-Y]'        => Charset.new([0, 'A'], ['Z', Charset::UNICODE_MAX]),
      '[^b-yB-Y]'     => Charset.new([0, 'A'], 'Z-a', ['z', Charset::UNICODE_MAX]),
      '[]'            => Char::NOTHING,
      '[^]'           => Char::ANY,
      '[\\^]'         => '^',
      '[A-Z'          => Charset.new('A-Z'),
      'a]-b[AB]]d'    => Char::Sequence.new([ 'a]-b', Charset.new('A', 'B'), ']d']),
      '['             => Char::NOTHING,
      '[^'            => Char::ANY,
      '[a-'           => Charset.new('a', '-'),
      '[--]]'         => Charset.new('--]'),
      '[a^{,}]'       => Charset.new('a', '^', '{', ',', '}'),
      '[a\-b]'        => Charset.new('a', '-', 'b'),
      '[a-\b]'        => Charset.new('a-b'),
      '[a-\\'         => Charset.new('a', '-', '\\'),
      '[\\'           => '\\',
      '[a/b]'         => Charset.new('a', '/', 'b'),
      '\\'            => '\\',

      '{}'            => [],
      '{,}'           => Char::Union.new([ [], [] ]),
      '{a,*,b*c,d}'   => Char::Union.new([ 'a', Char::STAR, Char::Sequence.new([ 'b', Char::STAR, 'c']), 'd' ]),
      '{a,b/*/c,d}'   => Char::Union.new([ 'a', Path::Sequence.new([ 'b', Char::STAR, 'c' ]), 'd']),
      'a{b,c}d'       => Char::Sequence.new([ 'a', Char::Union.new([ 'b', 'c' ]), 'd']),
      '{a,{b,c},d}'   => Char::Union.new([ 'a', 'b', 'c', 'd' ]),
      'a{}b'          => 'ab',
      'a{/}b'         => [ 'a', 'b' ],
      'a/{b}/c'       => [ 'a', 'b', 'c' ],
      'a,}b{c,d}}'    => Char::Sequence.new([ 'a,}b', Char::Union.new(['c', 'd']), '}' ]),

      'a/b/c'         => [ 'a', 'b', 'c' ],
      'abc/*/def'     => Path::Sequence.new([ 'abc', Char::STAR, 'def' ]),
      'a/b*c/d'       => Path::Sequence.new([ 'a', Char::Sequence.new([ 'b', Char::STAR, 'c' ]), 'd']),
      'a/b/c/d/e/f/g' => %w(a b c d e f g),

      'a//b'          => [ 'a', 'b' ],

      'a**b'          => Char::Sequence.new([ 'a', Path::GLOBSTAR, 'b' ]),
      'a/**/b'        => Path::Sequence.new([ 'a', Path::GLOBSTAR, 'b' ]),
      'a/b**c/d'      => Path::Sequence.new([ 'a', Char::Sequence.new([ 'b', Path::GLOBSTAR, 'c' ]), 'd' ]),
    }
    ABSOLUTE_TESTS = {
      '/'             => [],
      '/**'           => Path::GLOBSTAR,
      '///'           => [],
      '/{a,b}/'       => Char::Union.new(['a', 'b']),
      '{/a/b,/c/d}e'  => Char::Sequence.new([Char::Union.new([['a', 'b'], ['c', 'd']]), 'e']),
      '{a/b,/c/d}e'   => Char::Sequence.new([Char::Union.new([['a', 'b'], ['c', 'd']]), 'e']),
    }
    TAGS = {
      #'[a]' => [:focus]
    }

    TESTS.each do |input, expected|
      it "should parse #{input.inspect} as #{expected}", *(TAGS[input] || []) do
        result = bash.from(input)
        expect(result.expression).to eq expected
        expect(result.absolute?).to eq false
      end
    end

    ABSOLUTE_TESTS.each do |input, expected|
      it "should parse #{input.inspect} as #{expected}", *(TAGS[input] || []) do
        result = bash.from(input)
        expect(result.expression).to eq expected
        expect(result.absolute?).to eq true
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
