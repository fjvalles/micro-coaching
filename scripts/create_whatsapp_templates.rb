#!/usr/bin/env ruby
# Creates WhatsApp message templates via Meta Graph API.
# Run: asdf exec bundle exec rails runner scripts/create_whatsapp_templates.rb
#
# Optional:
#   TEMPLATE_DAYS=56 asdf exec bundle exec rails runner scripts/create_whatsapp_templates.rb

require "net/http"
require "json"
require "set"

$stdout.sync = true

WABA_ID  = ENV.fetch("META_BUSINESS_ACCOUNT_ID")
TOKEN    = ENV.fetch("META_ACCESS_TOKEN")
API_VER  = ENV.fetch("META_API_VERSION", "v25.0")
LOCALE   = ENV.fetch("PROGRAM_LOCALE", "es")
DAYS     = Integer(ENV.fetch("TEMPLATE_DAYS", "56"))
BASE_URL = "https://graph.facebook.com/#{API_VER}/#{WABA_ID}/message_templates"

def get_existing_template_names
  uri = URI("#{BASE_URL}?fields=name&limit=1000")
  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "Bearer #{TOKEN}"

  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) { |h| h.request(req) }
  json = JSON.parse(res.body)
  Array(json["data"]).map { |template| template["name"] }.compact.to_set
rescue => e
  puts "WARN could not list existing templates: #{e.message}"
  Set.new
end

def create_template(name:, body:, example_vars:)
  if $existing_template_names.include?(name)
    puts "  SKIP #{name} (already exists)"
    return
  end

  payload = {
    name: name,
    language: LOCALE,
    category: "UTILITY",
    components: [
      {
        type: "BODY",
        text: body,
        example: { body_text: [ example_vars ] }
      }
    ]
  }

  uri = URI(BASE_URL)
  req = Net::HTTP::Post.new(uri)
  req["Authorization"] = "Bearer #{TOKEN}"
  req["Content-Type"]  = "application/json"
  req.body = payload.to_json

  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) { |h| h.request(req) }
  json = JSON.parse(res.body)

  if json["id"]
    puts "  OK #{name}"
    $existing_template_names.add(name)
  else
    msg = json.dig("error", "error_user_msg") || json.dig("error", "message") || res.body
    puts "  FAIL #{name} -> #{msg}"
  end
rescue => e
  puts "  ERROR #{name} -> #{e.message}"
end

$existing_template_names = get_existing_template_names

puts "=== despertar_dia_XX (#{DAYS} templates) ==="
(1..DAYS).each do |day|
  create_template(
    name: "despertar_dia_%02d" % day,
    body: "Buenos dias {{1}}, aqui esta el mensaje de Impulso para comenzar tu dia de hoy:\n\n{{2}}\n\n— Impulso Coach",
    example_vars: [
      "Ana",
      "Hoy es un buen dia para cuidar tu rutina con un paso concreto."
    ]
  )
end

puts "\n=== iareto_dia_XX (#{DAYS} templates) ==="
(1..DAYS).each do |day|
  create_template(
    name: "iareto_dia_%02d" % day,
    body: "Hola {{1}}, aqui esta tu IAReto de Impulso para poner en practica durante el dia de hoy:\n\n{{2}}\n\n— Impulso Coach",
    example_vars: [
      "Ana",
      "Elige una tarea pequena, define el primer paso y hazlo por dos minutos."
    ]
  )
end

puts "\n=== checkin_dia_XX (#{DAYS} templates - 2 vars) ==="
(1..DAYS).each do |day|
  create_template(
    name: "checkin_dia_%02d" % day,
    body: "Hola {{1}}, es momento de tu check-in de Impulso. Responde con honestidad estas preguntas de reflexion sobre tu dia:\n\n{{2}}\n\n— Impulso Coach",
    example_vars: [
      "Ana",
      "1. Dormiste bien, regular o mal?\n\n2. Hiciste el reto de hoy?\n\n3. Que tarea pequena terminaste o dejaste lista?"
    ]
  )
end

puts "\nListo."
