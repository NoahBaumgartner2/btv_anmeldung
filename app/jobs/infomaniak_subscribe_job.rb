class InfomaniakSubscribeJob < ApplicationJob
  queue_as :newsletter

  retry_on InfomaniakNewsletterService::InfomaniakApiError,
           attempts: 3,
           wait: :polynomially_longer

  def perform(email, name: nil)
    InfomaniakNewsletterService.subscribe(email: email, name: name)
  end
end
