module ApplicationHelper
  def mask_last_four(value, placeholder: "•")
    return "—" if value.blank?
    str = value.to_s.strip.gsub(/\D/, "")
    return "—" if str.length < 4
    last_four = str[-4, 4]
    prefix_len = [ str.length - 4, 0 ].max
    "#{placeholder * prefix_len}#{last_four}"
  end
end
