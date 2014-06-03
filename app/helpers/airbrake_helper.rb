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
      markup = "@#{@htmlentities.decode(element[:file])}:#{element[:number]}@"
    else
      filename = @htmlentities.decode(filename_for_backtrace_element(element))

      if repository.identifier.blank?
        markup = "source:\"#{filename}#L#{element[:number]}\""
      else
        markup = "source:\"#{repository.identifier}|#{filename}#L#{element[:number]}\""
      end
    end

    markup + " in ??<notextile>#{@htmlentities.decode(element[:method])}</notextile>??"
  end

  private

  def repository_for_backtrace_element(element)
    return nil unless element[:file].start_with?('[PROJECT_ROOT]')

    filename = filename_for_backtrace_element(element)

    repositories_for_backtrace.find { |r| r.entry(filename) }
  end

  def repositories_for_backtrace
    return @_bactrace_repositories unless @_bactrace_repositories.nil?

    if @notice.params.key?(:repository)
      repo = @project.repositories.where(identifier: (@notice.params[:repository] || '')).first
      @_bactrace_repositories = [repo] if repo.present?
    else
      @_bactrace_repositories = @project.repositories.to_a
    end

    @_bactrace_repositories
  end

  def filename_for_backtrace_element(element)
    return nil if  element[:file].blank?

    element[:file][14..-1]
  end
end
