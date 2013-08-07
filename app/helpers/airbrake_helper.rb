module AirbrakeHelper

  def format_table(data)
    lines = []
    data.each do |key, value|
      next unless value.is_a?(String)
      lines << "|@#{key}@|#{value.strip.blank? ? value : "@#{value}@"}|"
    end
    lines.join("\n")
  end

  def format_log(data)
    lines = []
    data.each do |log|
      next unless log.is_a?(Hash)
      lines << "[#{log[:time].strftime('%F %T')}] #{log[:line]}"
    end
    lines.join("\n")
  end

  def format_list_item(name, value)
    return '' if value.blank?
    "* *#{name}:* #{value}"
  end

  def format_backtrace_element(element)
    @htmlentities ||= HTMLEntities.new

    repository = repository_for_backtrace_element(element)

    if repository.blank?
      file = "@#{@htmlentities.decode(element[:file])}:#{element[:number]}@"
    elsif repository.identifier.blank?
      file = "source:\"#{@htmlentities.decode(element[:file][14..-1])}#L#{element[:number]}\""
    else
      file = "source:\"#{repository.identifier}|#{@htmlentities.decode(element[:file][14..-1])}#L#{element[:number]}\""
    end

    file + " in ??<notextile>#{@htmlentities.decode(element[:method])}</notextile>??"
  end

  private

  def repository_for_backtrace_element(element)
    if element[:file].start_with?('[PROJECT_ROOT]')
      file = element[:file][14..-1]
      if @notice.params.key?(:repository)
        r = @project.repositories.where(identifier: (@notice.params[:repository] || '')).first
        return r if r.present? && r.entry(file)
      else
        return @project.repositories.select{|r| r.entry(file)}.first
      end
    end

    nil
  end

end
