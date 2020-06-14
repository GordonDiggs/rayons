class TracksController < ApplicationController
  include Pagy::Backend

  def index
    @track_finder = TrackFinder.new(track_finder_params)
    @artists = [nil] + Track.order(:artist).distinct.pluck(:artist)
    @pagy, @tracks = pagy(@track_finder.tracks)
  end

  private

  def track_finder_params
    params.permit(:name, :artist)
  end
end
