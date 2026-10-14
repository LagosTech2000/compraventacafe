# Whether the left navigation is collapsed to its icons. Kept in a cookie the
# browser sets (sidebar_controller.js), not in the user: the page comes from
# the server already in the right shape, and toggling it writes nothing.
module SidebarState
  COOKIE = "sidebar_collapsed"

  def self.collapsed?(cookies) = cookies[COOKIE] == "1"
end
