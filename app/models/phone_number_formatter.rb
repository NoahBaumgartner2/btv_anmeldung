# Normalisiert Schweizer Telefonnummern auf das Format "+41 79 123 45 67",
# unabhängig davon wie sie eingegeben wurden (mit/ohne Leerzeichen, mit 0 oder +41 etc.).
# Nicht erkennbare (z.B. ausländische) Nummern bleiben unverändert.
class PhoneNumberFormatter
  def self.call(value)
    digits = value.to_s.strip.gsub(/[^\d+]/, "")
    return value if digits.blank?

    national =
      if digits.start_with?("+41")
        digits.delete_prefix("+41")
      elsif digits.start_with?("0041")
        digits.delete_prefix("0041")
      elsif digits.start_with?("0")
        digits.delete_prefix("0")
      end

    return value unless national&.length == 9

    "+41 #{national[0, 2]} #{national[2, 3]} #{national[5, 2]} #{national[7, 2]}"
  end
end
