require 'support/spec_support'

describe 'super basic regex primitives' do
  include Superbasic

  context 'atom' do
    it_matches('a', 'b')
    it_does_not_match('a', 'b')
  end
end
