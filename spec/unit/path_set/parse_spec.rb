require 'support/spec_support'
require 'pathblazer/path_set/formats/bash'

describe Pathblazer::PathSet::Formats::Bash do

  let :bash do
    PathSet::Formats::Bash.new
  end

  context 'basic tokens' do
    it 'should read a as a path' do
      expect(bash.from('a').expression).to eq 'a'
    end

    it 'should read empty path' do
      expect(bash.from('').expression).to eq []
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
