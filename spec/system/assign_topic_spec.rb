# frozen_string_literal: true

describe "Assign | Assigning topics", type: :system, js: true do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:assign_modal) { PageObjects::Modals::Assign.new }
  fab!(:staff_user) { Fabricate(:user, groups: [Group[:staff]]) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.assign_enabled = true
    sign_in(admin)
  end

  describe "with open topic" do
    it "can assign and unassign" do
      visit "/t/#{topic.id}"

      topic_page.click_assign_topic
      assign_modal.assignee = staff_user
      assign_modal.confirm

      expect(topic_page).to have_assigned(user: staff_user, at_post: 2)
      expect(find("#topic .assigned-to")).to have_content(staff_user.username)

      topic_page.click_unassign_topic

      expect(topic_page).to have_unassigned(user: staff_user, at_post: 3)
      expect(page).to have_no_css("#topic .assigned-to")
    end

    context "when assigns are not public" do
      before { SiteSetting.assigns_public = false }

      it "assigned small action post has 'private-assign' in class attribute" do
        visit "/t/#{topic.id}"

        topic_page.click_assign_topic
        assign_modal.assignee = staff_user
        assign_modal.confirm

        expect(topic_page).to have_assigned(
          user: staff_user,
          at_post: 2,
          class_attribute: ".private-assign",
        )
      end
    end

    context "when unassign_on_close is set to true" do
      before { SiteSetting.unassign_on_close = true }

      it "unassigns the topic on close" do
        visit "/t/#{topic.id}"

        topic_page.click_assign_topic
        assign_modal.assignee = staff_user
        assign_modal.confirm

        expect(topic_page).to have_assigned(user: staff_user, at_post: 2)

        find(".topic-footer-main-buttons .toggle-admin-menu").click
        find(".topic-admin-close").click

        expect(find("#post_3")).to have_content(
          I18n.t("js.action_codes.closed.enabled", when: "just now"),
        )
        expect(page).to have_no_css("#post_4")
        expect(page).to have_no_css("#topic .assigned-to")
      end

      it "can assign the previous assignee" do
        visit "/t/#{topic.id}"

        topic_page.click_assign_topic
        assign_modal.assignee = staff_user
        assign_modal.confirm

        expect(topic_page).to have_assigned(user: staff_user, at_post: 2)

        find(".topic-footer-main-buttons .toggle-admin-menu").click
        find(".topic-admin-close").click

        expect(find("#post_3")).to have_content(
          I18n.t("js.action_codes.closed.enabled", when: "just now"),
        )
        expect(page).to have_no_css("#post_4")
        expect(page).to have_no_css("#topic .assigned-to")

        topic_page.click_assign_topic
        assign_modal.assignee = staff_user
        assign_modal.confirm

        expect(page).to have_no_css("#post_4")
        expect(find("#topic .assigned-to")).to have_content(staff_user.username)
      end

      context "when reassign_on_open is set to true" do
        before { SiteSetting.reassign_on_open = true }

        it "reassigns the topic on open" do
          visit "/t/#{topic.id}"

          topic_page.click_assign_topic
          assign_modal.assignee = staff_user
          assign_modal.confirm

          expect(topic_page).to have_assigned(user: staff_user, at_post: 2)

          find(".topic-footer-main-buttons .toggle-admin-menu").click
          find(".topic-admin-close").click

          expect(find("#post_3")).to have_content(
            I18n.t("js.action_codes.closed.enabled", when: "just now"),
          )
          expect(page).to have_no_css("#post_4")
          expect(page).to have_no_css("#topic .assigned-to")

          find(".topic-footer-main-buttons .toggle-admin-menu").click
          find(".topic-admin-open").click

          expect(find("#post_4")).to have_content(
            I18n.t("js.action_codes.closed.disabled", when: "just now"),
          )
          expect(page).to have_no_css("#post_5")
          expect(find("#topic .assigned-to")).to have_content(staff_user.username)
        end
      end
    end
  end
end
