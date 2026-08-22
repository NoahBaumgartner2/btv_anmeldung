# Normalisiert AHV-Nummern auf das Format "756.XXXX.XXXX.XX",
# unabhängig davon ob sie mit oder ohne Punkte eingegeben wurden.
# Unvollständige/ungültige Eingaben (nicht genau 13 Ziffern) bleiben unverändert.
class AhvNumberFormatter
  def self.call(value)
    digits = value.to_s.gsub(/\D/, "")
    return value unless digits.length == 13

    "#{digits[0, 3]}.#{digits[3, 4]}.#{digits[7, 4]}.#{digits[11, 2]}"
  end
end
