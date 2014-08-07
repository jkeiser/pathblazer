class X
  attr_accessor :h
  def hash
    h.hash
  end
end

x = X.new
x.h = { a: 1, b: 2 }

y = X.new
y.h = {}
y.h[:a] = 1
y.h[:b] = 2

puts x.hash
puts y.hash
