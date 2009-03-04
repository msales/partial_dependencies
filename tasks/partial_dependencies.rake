require 'stringio'

class PartialDependencies
  
  def initialize(base_path = File.expand_path(File.join(RAILS_ROOT,"app", "views")))
    @base_path = base_path
  end

  def base_path=(base_path)
    @base_path = base_path
    @views = nil
  end
  
  def dot(type = "png", view_set = "used", fn = "partial_dependencies")
    IO.popen("dot -T#{type} -o #{fn}-#{view_set}.#{type}", "w") do |pipe|
      pipe.puts dot_input(view_set)
    end
  end

  private

  def dot_input(view_set)
    possible_view_sets = ["used", "unused", "all"]
    unless possible_view_sets.include?(view_set)
      raise "Wrong view_set. Only #{possible_view_sets.inspect} possible. Was #{view_set.inspect}"
    end
    str = StringIO.new
    parse_files
    str.puts "digraph partial_dependencies {"
    name_to_node = {}
    instance_variable_get("@#{view_set}_views").each_with_index do |view, index|
      str.puts "Node#{index} [label=\"#{view}\"]"
      name_to_node[view] = "Node#{index}"
    end
    if (["used", "all"].include?(view_set))
      @edges.each do |view, partials|
        partials.each do |partial|
          str.puts "#{name_to_node[view]}->#{name_to_node[partial]}"
        end
      end
    end
    str.puts "}"
    str.rewind
    return str.read
  end

  
  def parse_files
    @edges = Hash.new {|hash,key| hash[key] = []}
    @used_views = {}
    @all_views = []
    views.each do |view|
      @all_views << pwfe(view)
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
    @unused_views = @all_views - @used_views
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
  task :generate_picture, :file_type, :view_set do |t, args|
    pd = PartialDependencies.new
    pd.dot(args.file_type || "png", args.view_set || "used")
  end
end
