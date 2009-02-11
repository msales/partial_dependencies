require 'stringio'

class PartialDependencies
  
  def initialize(base_path = "./app/views/")
    @base_path = base_path
  end

  def base_path=(base_path)
    @base_path = base_path
    @views = nil
  end
  
  def dot(fn)
    IO.popen("dot -Tpng -o #{fn}", "w") do |pipe|
      pipe.puts dot_input
    end
  end

  private

  def dot_input
    str = StringIO.new
    parse_files
    str.puts "digraph partial_dependencies {"
    name_to_node = {}
    @used_views.each_with_index do |view, index|
      str.puts "Node#{index} [label=\"#{view}\"]"
      name_to_node[view] = "Node#{index}"
    end
    @edges.each do |view, partials|
      partials.each do |partial|
        str.puts "#{name_to_node[view]}->#{name_to_node[partial]}"
      end
    end
    str.puts "}"
    str.rewind
    return str.read
  end

  
  def parse_files
    @edges = Hash.new {|hash,key| hash[key] = []}
    @used_views = {}
    views.each do |view|
      File.open("#{view[:path]}") do |contents|
        contents.each do |line|
          if line =~ /=\s*render.+:partial\s=>\s["'](.*)["']/
            partial_name = $1
            if partial_name.index("/")
              partial_name = partial_name.gsub(/\/([^\/]*)$/, "/_\\1")
            else
              partial_name = "#{File.dirname(view[:name])}/_#{partial_name}"
            end
            @edges[pwfe(view)] << partial_name
            @used_views[pwfe(view)] = true
            @used_views[partial_name] = true
          end
        end
      end
    end
    @used_views = @used_views.keys
  end
  
  def pwfe(view)
    view[:name].split(".")[0]
  end

  def views
    return @views if @views
    @views = Dir.glob(File.join(@base_path, "**", "*")).reject do |vp|
      File.directory?(vp)
    end.map {|vp| {:name => vp.gsub(@base_path, "").gsub(/^\//,''), :path => vp}}
  end
end


namespace :partial_dependencies do
  desc "Generate a graphical (PNG) representation of the partial dependencies"
  task :generate_picture do
    pd = PartialDependencies.new(File.expand_path(File.join(RAILS_ROOT,"app", "views")))
    pd.dot(File.join(RAILS_ROOT, "partial_dependencies.png"))
  end
end
