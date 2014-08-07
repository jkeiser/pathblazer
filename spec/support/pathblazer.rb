require 'pathblazer/path_set/formats/bash'

module

  def parse(str)
    results = []
    for index = 0; index < str.size; index++
      results << atom(str[index])
    end
    case results.size
    when 0
      empty
    when 1
      results[0]
    when 2
      sequence(results)
    end
  end

  def it_should_match_exactly(a,b)
    it "Should match #{b} to #{a} exactly" do
      a = parse(a)
      b = parse(b)
      match = Regex.partial_match(a,b)
      expect(match).matches.to == [ [ b, nil ] ]
      expect(match).matches[0][0].to === b
    end
  end

  def it_should_completely_fail_to_match(a,b,remaining)
    it "Should fail match #{b} to #{a} exactly" do
      a = parse(a)
      b = parse(b)
      match = Regex.partial_match(a,b)
      expect(match).matches.to == [ [ nil, remaining ] ]
      expect(match).matches[0][1].to === b
  end

  def it_should_restrict_match(a,b,restricted)
    it "Should match #{a} and #{b}, producing #{restricted}" do
      a = parse(a)
      b = parse(b)
      match = Regex.partial_match(a,b)
      expect(match).matches.to == [ [ restricted, nil ] ]
    end
  end
end
