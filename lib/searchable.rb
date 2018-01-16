require('chronic')

class Searchable
  attr_accessor :search_model
  attr_accessor :alias_fields
  attr_accessor :search_fields
  attr_accessor :command_fields

  def search(input)
    parts = split_parts(input)
    assigned_parts = parts.map(&method(:assign_part))
  end

  def deep_map(list, &fn)
    list.map { |x| x.is_a?(Array) ? deep_map(x, &fn) : fn.call(x) }
  end

  def my_scan(str, reg)
    scanned = str.scan(reg)
    return str if scanned.count == 1
    scanned
  end

  def assign_part(part)
    specials = %w(< <= | - >= >)
    if part.is_a?(String)
      return { type: :compare, search: part } if part.split(':')[1]
      return { type: :command, search: part } if part.split(/[<>]/)[1]
      return { type: :general, search: part }
    end
    return { type: :not, nest: part.drop(1).map(&method(:assign_part)) } if part.first == '-'
    return { type: :or, nest: (part - ['|']).map(&method(:assign_part)) } if part.include?('|')
  end

  def split_parts(initial_input)
    space_quote_scanner = /"[^"]*"|'[^']*'|[^\s]+/
    or_scanner = /\||[^|]+/
    # comp_scanner = /[<>]={0,1}|[^<>=]+/
    prefix_scanner = /^\-|.+/
    parts = initial_input.strip.scan(space_quote_scanner)
    parts = deep_map(parts) { |x| my_scan(x, or_scanner) }
    # parts = deep_map(parts) { |x| my_scan(x, comp_scanner) }
    parts = deep_map(parts) { |x| my_scan(x, prefix_scanner) }
    parts
  end

  def build_tree(inputs)
    parts = inputs.map do |input|
      build_part(search: input, negate: false, terminal: false)
    end
    return {} unless parts.any?
    return parts.first if parts.length == 1
    { '$and' => parts }
  end

  def build_part(part)
    search = part[:search]
    return build_or_parts(part) if search[/.+\|.+/]
    if search[/^-.+/]
      part[:search] = search[1..-1]
      part[:negate] = true
    end
    if alias_fields.any? { |k, _v| k.match(part[:search]) }
      return alias_part(part) unless part[:terminal]
    end
    build_search(part)
  end

  def build_or_parts(part)
    parts = part[:search].split('|')
    parts.map! do |x|
      x = clean_search(x)
      hash = { search: x, negate: part[:negate], terminal: part[:terminal] }
      build_part(hash)
    end
    op = part[:negate] ? '$and' : '$or'
    { op => parts }
  end

  def alias_part(part)
    current_alias = alias_fields.select { |k, _v| k.match(part[:search]) }
    k, v = current_alias.first
    v = v.call(part[:search], part) if v.is_a?(Proc)
    v = v.to_s if v.is_a?(Symbol)
    v = { search: v } if v.is_a?(String)
    part = part.merge(v)
    build_part(part)
  end

  def build_search(input)
    return build_compare_search(input) if input[:search][/^\w+[<>]=?.+/]
    return build_command(input) if is_command?(input)
    regex = /#{Regexp.quote(input[:search])}/im
    mapper = proc { |f| { f => regex } }
    mapper = proc { |f| { f.to_sym.not => regex } } if input[:negate]
    queries = search_fields.map(&mapper)
    return queries.first if queries.length == 1
    return { '$and' => queries } if input[:negate]
    { '$or' => queries }
  end

  def build_compare_search(search:, negate:, terminal:)
    front, back = search.split(/[<>]=?/)
    operator = search[/[<>]=?/]
    operator.sub!('=', 'e')
    operator.sub!('>', 'gt')
    operator.sub!('<', 'lt')
    if negate
      r_operator = operator.clone
      r_operator += 'e' unless operator['e']
      r_operator.sub!('e', '') if operator['e']
      r_operator.sub!('l', 'g') if operator['l']
      r_operator.sub!('g', 'l') if operator['g']
      operator = r_operator
    end
    field, type = field_details(front)
    back = back.to_i if type == Integer
    return build_time_compare(field, back, operator) if type == Time
    { field.send(operator) => back }
  end

  def build_time_compare(field, back, operator)
    date = guess_date(back, field)
    return {} unless date
    if @search_model.attribute_names.include?(field.to_s)
      { field.send(operator) => date }
    else
      start = date.send("beginning_of_#{field}")
      stop = date.send("end_of_#{field}")
      query_date = operator['l'] ? start : stop
      { :last_seen_at.send(operator) => query_date }
    end
  end

  def build_command(search:, negate:, terminal:)
    field, option = search.split(':')
    field, type = field_details(field)
    option = make_bson_objectid(option) if type == BSON::ObjectId
    return build_time_command(field, option, negate) if type == Time
    return build_bool_command(field, option, negate) if type == Boolean
    option = /#{Regexp.quote(option)}/im unless type == BSON::ObjectId
    return { field.to_sym.not => option } if negate
    { field => option }
  end

  def make_bson_objectid(string)
    return BSON::ObjectId.from_string(string) if BSON::ObjectId.legal?(string)
    string
  end

  def field_details(field)
    field = field.to_sym
    type = command_fields[field]
    return [field, String] unless type
    return [field, type] unless type.class == Symbol
    field_details(type)
  end

  def cast_bool(input)
    return input if input.class == Boolean
    return true if input == true || input.strip =~ /(true|t|yes|y|1)$/i
    return false if input == false || input.strip.blank? || input =~ /(false|f|no|n|0)$/i
    # input.include?('t') || input.include?('ye')
    # maybe throw error here or such
  end

  def build_bool_command(field, option, negate = false)
    option = cast_bool(option)
    option = !option if negate
    type = search_model.fields[field.to_s].type
    return { field => option } if type == Mongoid::Boolean
    return { field.to_sym.ne => nil } if option == true
    { field.to_sym => nil }
  end

  def build_time_command(field, option, negate = false)
    date = guess_date(option, field)
    return { created_at: nil } unless date
    start = date.send("beginning_of_#{field}")
    stop = date.send("end_of_#{field}")
    reverse = { '$or' => [{ :last_seen_at.gt => stop }, { :last_seen_at.lt => start }] }
    return reverse if negate
    { '$and' => [{ :last_seen_at.gt => start }, { :last_seen_at.lt => stop }] }
  end

  def guess_date(input, unit = nil)
    if unit.to_s == 'year' && input.to_s.length < 5
      date = input.to_i
      date += 2000 if date < 2000
      date = Chronic.parse("#{date}/1/1")
    else
      input.gsub!('_', ' ')
      date = Chronic.parse(input, context: :past)
    end
    date
  end
end
