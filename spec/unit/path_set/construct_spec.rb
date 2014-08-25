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
      'a'                                  => 'a',
      'abc'                                => 'abc',
      ''                                   => '',
      Char::STAR                           => '*',
      Path::GLOBSTAR                       => '**',
      [ 'a', 'b' ]                         => 'a/b',
      Char::Union.new([ 'a', 'b', 'c'])    => '{a,b,c}',
      Char::ANY                            => '?',
      '^-]},'                              => '^-]},',
      Charset.new('a-z')                   => '[a-z]',
      Charset.new('A-Z', 'a-z')            => '[A-Za-z]',
      Charset.new('A-Z', '0')              => '[0A-Z]',
      Charset.new('A-Z', '0', '2-9')       => '[02-9A-Z]',
      Charset.new('a', '-', 'z', ']', 'c') => '[-\\]acz]',
      Charset.new([0, 'A'], ['C', Charset::UNICODE_MAX]) => '[^B]',
      Charset.new([0, 'A'], ['Z', Charset::UNICODE_MAX]) => '[^B-Y]',
      Charset.new([0, 'A'], 'Z-a', ['z', Charset::UNICODE_MAX]) => '[^B-Yb-y]',
      Char::NOTHING                        => '[]',
      Char::ANY                            => '?',
      Charset.new('^')                     => '[\\^]',
      Charset.new('A-Z')                   => '[A-Z]',
      Char::Sequence.new([ 'a]-b', Charset.new('A', 'B'), ']d']) => 'a]-b[AB]]d',
      Charset.new('a', '-')                => '[-a]',
      Charset.new('a', '^', '{', ',', '}') => '[,^a{}]',
      Charset.new('a', '-', 'b')           => '[-ab]',
      Charset.new('a-b')                   => '[a-b]',
      Charset.new('a', '-', '\\')          => '[-\\\\a]',
      '\\'                                 => '\\',
      Charset.new('--]')                   => '[--]]',
      []                                   => '',
      Char::Union.new([ [], [] ])          => '{,}',
      Char::Union.new([ 'a', Char::STAR, Char::Sequence.new([ 'b', Char::STAR, 'c']), 'd' ]) => '{a,*,b*c,d}',
      Char::Union.new([ 'a', Path::Sequence.new([ 'b', Char::STAR, 'c' ]), 'd']) => '{a,b/*/c,d}',
      Char::Sequence.new([ 'a', Char::Union.new([ 'b', 'c' ]), 'd']) => 'a{b,c}d',
      Char::Union.new([ 'a', 'b', 'c', 'd' ]) => '{a,b,c,d}',
      'ab'                                 => 'ab',
      [ 'a', 'b' ]                         => 'a{/}b',
      [ 'a', 'b', 'c' ]                    => 'a/{b}/c',
      Char::Sequence.new([ 'a,}b', Char::Union.new(['c', 'd']), '}' ]) => 'a,}b{c,d}}',
      [ 'a', 'b', 'c' ]                    => 'a/b/c',
      Path::Sequence.new([ 'abc', Char::STAR, 'def' ]) => 'abc/*/def',
      Path::Sequence.new([ 'a', Char::Sequence.new([ 'b', Char::STAR, 'c' ]), 'd']) => 'a/b*c/d',
      %w(a b c d e f g)                    => 'a/b/c/d/e/f/g',
      [ 'a', 'b' ]                         => 'a/b',
      Char::Sequence.new([ 'a', Path::GLOBSTAR, 'b' ]) => 'a**b',
      Path::Sequence.new([ 'a', Path::GLOBSTAR, 'b' ]) => 'a/**/b',
      Path::Sequence.new([ 'a', Char::Sequence.new([ 'b', Path::GLOBSTAR, 'c' ]), 'd' ]) => 'a/b**c/d',
    }
    ABSOLUTE_TESTS = {
      []                          => '/',
      Path::GLOBSTAR              => '/**',
      Char::Union.new(['a', 'b']) => '/{a,b}',
      Char::Sequence.new([Char::Union.new([['a', 'b'], ['c', 'd']]), 'e']) => '/{a/b,c/d}e',
      Char::Sequence.new([Char::Union.new([['a', 'b'], ['c', 'd']]), 'e']) => '/{a/b,c/d}e',
    }
    TAGS = {
      #'[a]' => [:focus]
    }

    TESTS.each do |input, expected|
      it "should format #{input} as glob #{expected}", *(TAGS[input] || []) do
        result = bash.to_glob(PathSet.new(input, false))
        expect(result).to eq expected
      end
    end

    ABSOLUTE_TESTS.each do |input, expected|
      it "should format #{input} as glob #{expected}", *(TAGS[input] || []) do
        result = bash.to_glob(PathSet.new(input, true))
        expect(result).to eq expected
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

    it "Throws an exception when processing [a/b]" do
      expect { bash.to_glob(PathSet.new(Charset.new('a', '/', 'b'), false)) }.to raise_error(Pathblazer::PathNotSupportedError)
    end
  end
end
