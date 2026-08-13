# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Provisioning', type: :request do
  path '/api/v1/provisioning' do
    post 'Provision a fully-onboarded Ordi user' do
      tags 'Provisioning'
      security [ { ordiSecretAuth: [] } ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :provisioning, in: :body, required: true,
                schema: {
                  type: :object,
                  required: [ 'email' ],
                  properties: {
                    email: { type: :string, format: :email },
                    first_name: { type: :string },
                    last_name: { type: :string },
                    time_zone: { type: :string },
                    currency: { type: :string, enum: [ 'BRL' ], description: 'BRL only' },
                    locale: { type: :string },
                    initial_account: {
                      type: :object,
                      properties: {
                        name: { type: :string },
                        balance: { type: :number },
                        currency: { type: :string, enum: [ 'BRL' ] },
                        subtype: { type: :string }
                      }
                    }
                  }
                }

      response '201', 'user provisioned' do
        schema type: :object,
               required: %w[created user family account],
               properties: {
                 created: { type: :boolean },
                 user: { type: :object },
                 family: { type: :object },
                 account: { type: :object, nullable: true }
               }
      end

      response '200', 'user already existed' do
        schema '$ref' => '#/components/schemas/ProvisioningResponse'
      end

      response '422', 'invalid or unsupported currency' do
        schema '$ref' => '#/components/schemas/ErrorResponse'
      end
    end
  end
end
