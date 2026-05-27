#!/usr/bin/env ruby
# Creates all 43 WhatsApp message templates via Meta Graph API.
# Run: asdf exec bundle exec rails runner scripts/create_whatsapp_templates.rb

require "net/http"
require "json"

WABA_ID  = ENV.fetch("META_BUSINESS_ACCOUNT_ID")
TOKEN    = ENV.fetch("META_ACCESS_TOKEN")
API_VER  = ENV.fetch("META_API_VERSION", "v25.0")
LOCALE   = "es"
BASE_URL = "https://graph.facebook.com/#{API_VER}/#{WABA_ID}/message_templates"

def create_template(name:, body:, example_vars:)
  payload = {
    name: name,
    language: LOCALE,
    category: "UTILITY",
    components: [
      {
        type: "BODY",
        text: body,
        example: { body_text: [example_vars] }
      }
    ]
  }

  uri = URI(BASE_URL)
  req = Net::HTTP::Post.new(uri)
  req["Authorization"] = "Bearer #{TOKEN}"
  req["Content-Type"]  = "application/json"
  req.body = payload.to_json

  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  json = JSON.parse(res.body)

  if json["id"]
    puts "  OK #{name}"
  else
    msg = json.dig("error", "error_user_msg") || json.dig("error", "message") || res.body
    puts "  FAIL #{name} -> #{msg}"
  end
rescue => e
  puts "  ERROR #{name} -> #{e.message}"
end

puts "=== despertar_dia_XX (14 templates) ==="
(1..14).each do |day|
  create_template(
    name: "despertar_dia_%02d" % day,
    body: "Buenos dias {{1}}, aqui esta el mensaje de Impulso para comenzar tu dia de hoy:\n\n{{2}}\n\n— Impulso Coach",
    example_vars: [
      "Ana",
      "Hoy es un buen dia para observar un nuevo patron en tu trabajo."
    ]
  )
end

puts "\n=== iareto_dia_XX (14 templates) ==="
(1..14).each do |day|
  create_template(
    name: "iareto_dia_%02d" % day,
    body: "Hola {{1}}, aqui esta tu IAReto de Impulso para poner en practica durante el dia de hoy:\n\n{{2}}\n\n— Impulso Coach",
    example_vars: [
      "Ana",
      "Identifica tres momentos clave durante el dia y observalos sin intervenir."
    ]
  )
end

puts "\n=== checkin_dia_XX (14 templates — 2 vars) ==="
(1..14).each do |day|
  create_template(
    name: "checkin_dia_%02d" % day,
    body: "Hola {{1}}, es momento de tu check-in de Impulso. Responde con honestidad estas preguntas de reflexion sobre tu dia:\n\n{{2}}\n\n— Impulso Coach",
    example_vars: [
      "Ana",
      "1. En que momento lideraste mas en automatico hoy?\n\n2. Donde estuviste mas presente?\n\n3. Que te llamo la atencion de esa diferencia?"
    ]
  )
end

puts "\nListo."
