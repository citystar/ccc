$:.unshift(File.dirname(File.expand_path(__FILE__)) + '/lib')
require 'my_bitflyer'
require 'pry-byebug'

# Action object for Bitcoin.
btc = Bitflyer.btc
puts btc.price