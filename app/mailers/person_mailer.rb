class PersonMailer < ApplicationMailer
	add_template_helper(ApplicationHelper)
	add_template_helper(SubscriptionsHelper)
	include SubscriptionsHelper
  include ApplicationHelper

	def join_form_notice(person, join_form, request)
		@person = person
		@join_form = join_form
		@request = request
		mail(from: from(request), to: person.email, subject: "#{join_form.person.display_name} has created a join_form.")
	end

	def private_email(to, from, subject, body, request)
		@body = body
		mail(from: from.email, to: to.email, bcc: from.email, subject: subject)
	end

	def verify_email(subscription, subscription_params, host)
		@subscription = subscription
		uri = Addressable::URI.parse("https://#{host}#{subscription_form_path(@subscription)}")
		
		# TODO refactor to share helper flattening for callback
		params = flatten_subscription_params(subscription_params)
		uri.query_values = (uri.query_values || {}).merge(params)
		@url = uri.to_s

		headers[:bcc]= 'lrohde@nuw.org.au'

		mail(from: "noreply@#{host}", to: subscription.person.email, subject: t('subscriptions.verify_email.subject'))
	end

	def duplicate_notice(subscription, params, host)
		@subscription = subscription
		@params = params
		mail(from: "noreply@#{host}", to: 'lrohde@nuw.org.au', subject: "We may be duplicating a member")
	end

	def temp_alert(subscription, host)
		@subscription = subscription
		subject = "#{@subscription.person.present? ? @subscription.person.display_name : 'unknown' } - #{@subscription.step}"
		mail(from: "noreply@#{host}", to: 'lrohde@nuw.org.au', subject: subject)
	end

	def incomplete_join_notice(subscription, host, email)
		@subscription = subscription
		subject = "#{@subscription.person.present? ? @subscription.person.display_name : 'unknown' } didn't join - #{@subscription.step}"
		mail(from: "noreply@#{host}", to: email, subject: subject)
	end

	def join_notice(subscription, host, email)
		@subscription = subscription
		subject = "#{@subscription.person.present? ? @subscription.person.display_name : 'unknown' } joined - #{@subscription.step}"
		mail(from: "noreply@#{host}", to: email, subject: subject)
	end

	def attach_pdf(subscription, email)
		#PersonMailer.attach_pdf(Subscription.find_by_token('21TBslpIDBcDaO-C76GVBg'), 'lrohde@nuw.org.au').deliver_now
		@subscription = subscription
		@subscription_url = "#{edit_join_url(subscription.join_form.union.short_name, subscription.join_form.short_name, subscription.token, locale: 'en', with_sig: true)}"
		attachments["join_form_#{subscription.external_id || subscription.token}.pdf"] = WickedPdf.new.pdf_from_url(@subscription_url)
		subject = "Join Form for #{subscription.person.display_name}"
		mail(from: @subscription.join_form.person.email, to: email, subject: subject )
	end

private
	def from(request)
		"noreply@#{request.host}".gsub("www.", "")
	end

	def host
		ENV['mailgun_host']
	end

end
