class InfomaniakUnsubscribeJob < ApplicationJob
  queue_as :newsletter

  retry_on InfomaniakNewsletterService::InfomaniakApiError,
           attempts: 3,
           wait: :polynomially_longer

  def perform(email)
    InfomaniakNewsletterService.unsubscribe(email: email)
  end
end
