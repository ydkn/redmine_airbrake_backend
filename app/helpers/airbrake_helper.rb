module AirbrakeHelper
  # Error title
  def airbrake_error_title(error)
    if error.type.blank?
      error.message
    else
      "#{error.type}: #{error.message}"
    end
  end

  # Wiki markup for a table
  def airbrake_format_table(data)
    lines = []

    data.each do |key, value|
      next if value.blank?

      if value.is_a?(String)
        lines << "|@#{key}@|@#{value}@|"
      elsif value.is_a?(Hash)
        lines << "|@#{key}@|@#{value.map { |k, v| "#{k}: #{v}" }.join(', ')}@|"
      end
    end

    lines.join("\n")
  end

  # Wiki markup for a list item
  def airbrake_format_list_item(name, value)
    return '' if value.blank?

    "* *#{name}:* #{value}"
  end

  # Wiki markup for backtrace element with link to repository if possible
  def airbrake_format_backtrace_element(element)
    repository = airbrake_repository_for_backtrace_element(element)

    if repository.blank?
      if element.line.blank?
        markup = "@#{element.file}@"
      else
        markup = "@#{element.file}:#{element.line}@"
      end
    else
      filename = airbrake_filename_for_backtrace_element(element)

      if repository.identifier.blank?
        markup = "source:\"#{filename}#L#{element.line}\""
      else
        markup = "source:\"#{repository.identifier}|#{filename}#L#{element.line}\""
      end
    end

    markup + " in ??<notextile>#{element.function}</notextile>??"
  end

  def airbrake_render_section(data, section)
    render partial: 'airbrake/issue_description/section', locals: { data: data, section: section }
  end

  private

  def airbrake_repository_for_backtrace_element(element)
    return nil unless element.file.start_with?('[PROJECT_ROOT]')

    filename = airbrake_filename_for_backtrace_element(element)

    airbrake_repositories_for_backtrace.find { |r| r.entry(filename) }
  end

  def airbrake_repositories_for_backtrace
    return @_bactrace_repositories unless @_bactrace_repositories.nil?

    if @repository.present?
      @_bactrace_repositories = [@repository]
    else
      @_bactrace_repositories = @project.repositories.to_a
    end

    @_bactrace_repositories
  end

  def airbrake_filename_for_backtrace_element(element)
    return nil if  element.file.blank?

    element.file[14..-1]
  end
end
