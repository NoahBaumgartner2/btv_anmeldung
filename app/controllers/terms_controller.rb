class TermsController < ApplicationController
  before_action :set_term, only: %i[ edit update destroy ]
  before_action :authorize_admin!

  # GET /terms
  def index
    @terms = Term.order(start_date: :desc)
  end

  # GET /terms/new
  def new
    @term = Term.new
  end

  # GET /terms/1/edit
  def edit
  end

  # POST /terms
  def create
    @term = Term.new(term_params)
    if @term.save
      redirect_to terms_path, notice: "Semester/Quartal wurde erfolgreich gespeichert."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /terms/1
  def update
    if @term.update(term_params)
      redirect_to terms_path, notice: "Semester/Quartal wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /terms/1
  def destroy
    @term.destroy!
    redirect_to terms_path, notice: "Semester/Quartal wurde entfernt."
  end

  private
    def set_term
      @term = Term.find(params.expect(:id))
    end

    def term_params
      params.expect(term: [ :name, :kind, :start_date, :end_date ])
    end
end
