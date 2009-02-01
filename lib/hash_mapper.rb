$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module HashMapper
  VERSION = '0.0.2'
  
  def maps
    @maps ||= []
  end
  
  def map(from, to, &blk)
    to.filter = blk if block_given?
    self.maps << [from, to]
  end
  
  def from(path, coerce_method = nil)
    PathMap.new(path, coerce_method)
  end
  
  alias :to :from
  
  def translate(incoming_hash)
    output = {}
    incoming_hash = simbolize_keys(incoming_hash)
    maps.each do |path_from, path_to|
        path_to.inject(output){|h,e|
          if h[e]
            h[e]
          else
            h[e] = (e == path_to.last ? path_to.resolve_value(path_from, incoming_hash) : {})
          end
        }
    end
    output
  end
  
  # from http://www.geekmade.co.uk/2008/09/ruby-tip-normalizing-hash-keys-as-symbols/
  #
  def simbolize_keys(hash)
    hash.inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end
  
  # This allows us to pass mapper classes as block arguments
  #
  def to_proc
    Proc.new{|*args| self.translate(*args)}
  end
  
  class PathMap
    
    include Enumerable
    
    attr_reader :segments
    
    attr_writer :filter
    
    def initialize(path, coerce_method = nil)
      @path = path.dup
      @coerce_method = coerce_method
      @index = extract_array_index!(path)
      @segments = parse(path)
      @filter = lambda{|value| value}# default filter does nothing
    end
    
    def resolve_value(another_path, incoming_hash)
      coerce another_path.extract_value_from(incoming_hash)
    end
    
    def coerce(value)
      value = @filter.call(value)
      return value unless @coerce_method
      value.send(@coerce_method) rescue value
    end
    
    def extract_value_from(incoming_hash)
      value = inject(incoming_hash){|hh,ee| hh[ee]}
      return value unless @index
      value.to_a[@index]
    end
    
    def each(&blk)
      @segments.each(&blk)
    end
    
    def last
      @segments.last
    end
    
    private
    
    def extract_array_index!(path)
      path.gsub! /(\[[0-9]+\])/, ''
      if idx = $1
        idx.gsub(/(\[|\])/, '').to_i
      else
        nil
      end
    end
    
    def parse(path)
      p = path.split('/')
      p.shift
      p.collect{|e| e.to_sym}
    end
    
  end
  
end