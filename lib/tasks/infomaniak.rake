namespace :infomaniak do
  desc "Enqueued Subscribe-Jobs für alle lokalen NewsletterSubscribers mit Status 'subscribed'. " \
       "Gedacht für den initialen Import (z.B. ~8'000 Abonnenten). " \
       "Jobs werden in 100er-Batches enqueued, jedes Batch 10s später ausgeführt " \
       "(via set(wait:)) – ergibt ~10 req/s und verhindert API-Rate-Limit-Fehler."
  task sync_all: :environment do
    unless InfomaniakConfig.configured?
      puts "Infomaniak nicht konfiguriert – sync_all übersprungen."
      puts "Bitte api_token und mailing_list_id via `bin/rails credentials:edit` setzen."
      next
    end

    total    = NewsletterSubscriber.subscribed.count
    enqueued = 0

    puts "Starte Infomaniak sync_all: #{total} Abonnenten werden enqueued..."

    NewsletterSubscriber.subscribed.find_each(batch_size: 100) do |subscriber|
      # 10s Abstand pro 100er-Batch → ~10 req/s auf Worker-Seite.
      # Bei 8'000 Abonnenten: 80 Batches × 10s = ~13 Minuten Gesamtlaufzeit.
      batch_index = enqueued / 100
      InfomaniakSubscribeJob
        .set(wait: (batch_index * 10).seconds)
        .perform_later(subscriber.email, name: subscriber.name)

      enqueued += 1
      puts "  #{enqueued}/#{total} enqueued (Batch #{batch_index + 1}, früheste Ausführung in #{batch_index * 10}s)..." if (enqueued % 100).zero?
    end

    puts "Fertig: #{enqueued} Subscribe-Jobs enqueued, verteilt über ~#{(enqueued / 100) * 10} Sekunden."
  end
end
