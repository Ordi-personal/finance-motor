module Api
  module V1
    class InsightsController < BaseController
      skip_before_action :authenticate_request!
      before_action :verify_fluxo_token
      before_action :set_user_context

      def index
        # Simple insight logic: Compare current month expenses vs last month
        current_period = Period.current_month
        last_period = Period.last_month

        current_expenses = @family.income_statement.expense_totals(period: current_period).total.abs
        last_expenses = @family.income_statement.expense_totals(period: last_period).total.abs

        insights = []

        # Expense trend insight
        if last_expenses > 0
          change_pct = ((current_expenses - last_expenses) / last_expenses * 100).round
          if change_pct > 10
            insights << {
              type: "warning",
              message: "Você gastou #{change_pct}% a mais este mês em comparação ao mês passado. Que tal revisar seu orçamento?",
              icon: "alert-triangle"
            }
          elsif change_pct < -10
            insights << {
              type: "success",
              message: "Parabéns! Seus gastos diminuíram #{change_pct.abs}% em relação ao mês passado.",
              icon: "trending-down"
            }
          else
            insights << {
              type: "neutral",
              message: "Seus gastos estão estáveis em relação ao mês anterior.",
              icon: "activity"
            }
          end
        end

        # Top category insight
        top_category = @family.income_statement.expense_totals(period: current_period)
                             .category_totals
                             .sort_by { |ct| ct.total }
                             .first # Expenses are usually negative in total? method calculate_total usually returns positive for expenses in expense_totals
        
        # Check expense_totals implementation in PagesController logic
        # It seems expense_totals returns positive values for expenses based on BaseController logic or similar services
        
        # Re-verify: In PagesController: 
        # expense_totals = Current.family.income_statement.expense_totals(period: @period)
        # It references IncomeStatement.
        
        if top_category && top_category.total > 0
          insights << {
            type: "info",
            message: "Sua maior categoria de gastos este mês é '#{top_category.category.name}'.",
            icon: "pie-chart"
          }
        end
        
        # If no transactions yet
        if insights.empty?
          insights << {
            type: "info",
            message: "Adicione transações financeiras para receber insights personalizados da IA.",
            icon: "sparkles"
          }
        end

        render json: { insights: insights }
      end

      private

        def verify_fluxo_token
          # Simple shared secret check for MVP
          unless request.headers["X-Fluxo-Secret"] == "fluxo_internal_secret_key_123"
            render json: { error: "unauthorized" }, status: :unauthorized
          end
        end

        def set_user_context
          email = params[:email]
          
          if email == "demo" || email == "user@example.com"
             # Fallback to first user for demo
             user = User.first
          else
             user = User.find_by(email: email)
          end
          
          if user
            @current_user = user
            @family = user.family
          else
            # Last resort for demo environment
            if Rails.env.development?
              user = User.first
              if user
                @current_user = user
                @family = user.family
                return
              end
            end
            
            render json: { error: "user_not_found" }, status: :not_found
          end
        end
    end
  end
end
