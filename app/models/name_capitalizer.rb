# Macht den ersten Buchstaben jedes Worts gross (z.B. "hans müller" ->
# "Hans Müller", "van der berg" -> "Van Der Berg"). Wortgrenzen sind
# Leerzeichen und Bindestriche, damit auch Doppelnamen wie "Müller-Schmid"
# korrekt formatiert werden. Der Rest des Worts bleibt unverändert.
class NameCapitalizer
  def self.call(value)
    return value if value.blank?

    value.split(/([\s-])/).map { |part| part.match?(/\A\p{L}/) ? part[0].upcase + part[1..] : part }.join
  end
end
