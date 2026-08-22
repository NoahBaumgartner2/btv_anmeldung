# Normalisiert IBANs auf 4er-Gruppen ("CH56 0483 5012 3456 7800 9"),
# unabhängig von Gross-/Kleinschreibung oder vorhandenen Leerzeichen.
class IbanFormatter
  def self.call(value)
    chars = value.to_s.gsub(/\s/, "").upcase
    return value if chars.blank?

    chars.scan(/.{1,4}/).join(" ")
  end
end
