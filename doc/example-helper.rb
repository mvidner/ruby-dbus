# Fin
$:.unshift File.expand_path("../../lib", __FILE__)
load 'ex-setup.rb'
def example(filename)
  eval(File.read(filename), binding, filename, 1)
end
