class ItemsController < ApplicationController
  include ApplicationHelper

  before_filter :authorize_item, :only => [:new, :edit, :create, :update, :import, :destroy]
  before_filter :edit_discogs_param, :only => [:index, :create, :update]
  after_filter :expire_pages, :only => [:new, :edit, :create, :update, :import, :destroy]

  caches_action :show, :if => Proc.new{ |c| !c.request.format.json? }

  # GET /
  # GET /items
  # GET /items.json
  # GET /items.csv
  def index
    @can_edit = policy(Item).edit?

    respond_to do |format|
      format.html
      format.json do
        json = Rails.cache.fetch(["items_json", Item.unscoped.maximum(:updated_at).to_i, params.slice(:sort, :direction, :search, :page)]) do
          page = [params[:page].to_i, 1].max
          @items = Item.sorted(params[:sort], params[:direction]).search(params[:search]).page(page)
          pagination = PageEntriesInfoDecorator.new(@items)
          markup = render_to_string(partial: 'items/pagination', formats: [:html]).gsub(/.json/, '')
          {items: @items, page: page, pagination: markup}.merge(pagination.as_json).to_json
        end
        render text: json
      end
      format.csv do
        set_streaming_headers
        filename = "rayons_#{Time.now.to_i}.csv"
        headers["Content-Type"] = "text/csv"
        headers["Content-disposition"] = "attachment; filename=\"#{filename}\""

        response.status = 200

        # Stream output to client
        self.response_body = Enumerator.new do |e|
          Item.to_csv { |i| e << i }
        end
      end
    end
  end

  # GET /items/latest.json
  def latest
    number_of_items = params[:num].to_i
    number_of_items = 5 if number_of_items.zero?
    @items = Item.order('created_at DESC').limit(number_of_items)
    render json: @items
  end

  # GET /items/1
  # GET /items/1.json
  def show
    @item = Item.find(params[:id])

    respond_to do |format|
      format.html { @release = DiscogsRelease.new(@item) }
      format.json { render json: @item }
    end
  end

  # GET /items/new
  # GET /items/new.json
  def new
    @item = Item.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @item }
    end
  end

  # GET /items/1/edit
  def edit
    @item = Item.find(params[:id])
  end

  # POST /items
  # POST /items.json
  def create
    @item = Item.new(item_params)

    respond_to do |format|
      if @item.save
        format.html { redirect_to @item, notice: 'Item was successfully created.' }
        format.json { render json: @item.as_json.merge(item_markup: render_to_string(:partial => 'items/item', :formats => [:html], :locals=>{:item => @item})), status: :created, location: @item }
      else
        default_error_response(format, "new", @item)
      end
    end
  end

  # PUT /items/1
  # PUT /items/1.json
  def update
    @item = Item.find(params[:id])
    params[:item] = params[:item].reject { |k,v| !Item.column_names.include?(k) }

    respond_to do |format|
      if @item.update_attributes(item_params)
        format.html { redirect_to @item, notice: 'Item was successfully updated.' }
        format.json { head :no_content }
      else
        default_error_response(format, "edit", @item)
      end
    end
  end

  # DELETE /items/1
  # DELETE /items/1.json
  def destroy
    @item = Item.find(params[:id])
    @item.destroy

    respond_to do |format|
      format.html { redirect_to items_url }
      format.json { head :no_content }
    end
  end

  # POST /items/import
  def import
    @items = Item.import_csv_file(params[:file])
    flash[:notice] = "Imported #{@items.count} items"

  rescue => e
    flash[:error] = "Error importing: #{e}"
    Rails.logger.warn("!!! Error importing CSV: #{e}")
    Rails.logger.warn(e.backtrace.join("\n"))
  ensure
    redirect_to '/'
  end

  # GET /items/random
  # GET /items/random.json
  def random
    @item = Item.offset(rand(Item.count)).first

    respond_to do |format|
      format.html { redirect_to @item }
      format.json { render json: @item }
    end
  end

  private

  def authorize_item
    authorize Item
  end

  def expire_pages
    expire_page :controller => :stats, :action => :index
    expire_page :controller => :stats, :action => :counts_by_day
    expire_action :controller => :items, :action => :show, :id => @item.id if @item
  end

  def edit_discogs_param
    params[:sort] = 'discogs_url' if params[:sort] == 'discogs'
    if params[:item]
      params[:item][:discogs_url] ||= params[:item][:discogs]
    end
  end

  def item_params
    params.require(:item).permit(:artist, :condition, :format, :label, :price_paid, :title, :year, :color, :discogs_url)
  end
end
