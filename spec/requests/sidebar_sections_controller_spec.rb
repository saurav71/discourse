# frozen_string_literal: true

RSpec.describe SidebarSectionsController do
  fab!(:user) { Fabricate(:user) }

  before do
    ### TODO remove when enable_custom_sidebar_sections SiteSetting is removed
    group = Fabricate(:group)
    Fabricate(:group_user, group: group, user: user)
    SiteSetting.enable_custom_sidebar_sections = group.id.to_s
  end

  describe "#create" do
    it "is not available for anonymous" do
      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             links: [
               { name: "categories", value: "/categories" },
               { name: "tags", value: "/tags" },
             ],
           }

      expect(response.status).to eq(403)
    end

    it "creates custom section for user" do
      sign_in(user)
      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             links: [
               { name: "categories", value: "/categories" },
               { name: "tags", value: "/tags" },
             ],
           }

      expect(response.status).to eq(200)

      expect(SidebarSection.count).to eq(1)
      sidebar_section = SidebarSection.last

      expect(sidebar_section.title).to eq("custom section")
      expect(sidebar_section.user).to eq(user)
      expect(sidebar_section.sidebar_urls.count).to eq(2)
      expect(sidebar_section.sidebar_urls.first.name).to eq("categories")
      expect(sidebar_section.sidebar_urls.first.value).to eq("/categories")
      expect(sidebar_section.sidebar_urls.second.name).to eq("tags")
      expect(sidebar_section.sidebar_urls.second.value).to eq("/tags")
    end
  end

  describe "#update" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }
    fab!(:sidebar_url_1) { Fabricate(:sidebar_url, name: "tags", value: "/tags") }
    fab!(:sidebar_url_2) { Fabricate(:sidebar_url, name: "categories", value: "/categories") }
    fab!(:section_link_1) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    end
    fab!(:section_link_2) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)
    end

    it "allows user to update their own section and links" do
      sign_in(user)
      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [
              { id: sidebar_url_1.id, name: "latest", value: "/latest" },
              { id: sidebar_url_2.id, name: "tags", value: "/tags", _destroy: "1" },
            ],
          }

      expect(response.status).to eq(200)

      expect(sidebar_section.reload.title).to eq("custom section edited")
      expect(sidebar_url_1.reload.name).to eq("latest")
      expect(sidebar_url_1.value).to eq("/latest")
      expect { section_link_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { sidebar_url_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "doesn't allow to edit other's sections" do
      sidebar_section_2 = Fabricate(:sidebar_section)
      sidebar_url_3 = Fabricate(:sidebar_url, name: "other_tags", value: "/tags")
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section_2, linkable: sidebar_url_3)
      sign_in(user)
      put "/sidebar_sections/#{sidebar_section_2.id}.json",
          params: {
            title: "custom section edited",
            links: [{ id: sidebar_url_3.id, name: "takeover", value: "/categories" }],
          }

      expect(response.status).to eq(403)
    end

    it "doesn't allow to edit other's links" do
      sidebar_url_3 = Fabricate(:sidebar_url, name: "other_tags", value: "/tags")
      Fabricate(
        :sidebar_section_link,
        sidebar_section: Fabricate(:sidebar_section),
        linkable: sidebar_url_3,
      )
      sign_in(user)
      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [{ id: sidebar_url_3.id, name: "takeover", value: "/categories" }],
          }

      expect(response.status).to eq(404)

      expect(sidebar_url_3.reload.name).to eq("other_tags")
    end
  end

  describe "#destroy" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }

    it "allows user to delete their own section" do
      sign_in(user)
      delete "/sidebar_sections/#{sidebar_section.id}.json"

      expect(response.status).to eq(200)

      expect { sidebar_section.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "doesn't allow to delete other's sidebar section" do
      sidebar_section_2 = Fabricate(:sidebar_section)
      sign_in(user)
      delete "/sidebar_sections/#{sidebar_section_2.id}.json"

      expect(response.status).to eq(403)
    end
  end
end
