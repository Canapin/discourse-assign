# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::AssignNotification do
  describe "#execute" do
    fab!(:user1) { Fabricate(:user, last_seen_at: 1.day.ago) }
    fab!(:user2) { Fabricate(:user, last_seen_at: 1.day.ago) }
    fab!(:topic) { Fabricate(:topic, title: "Basic topic title") }
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:pm_post) { Fabricate(:private_message_post) }
    fab!(:pm) { pm_post.topic }
    fab!(:assign_allowed_group) { Group.find_by(name: "staff") }

    def assert_publish_topic_state(topic, user)
      message = MessageBus.track_publish("/private-messages/assigned") { yield }.first

      expect(message.data[:topic_id]).to eq(topic.id)
      expect(message.user_ids).to eq([user.id])
    end

    before { assign_allowed_group.add(user1) }

    describe "User" do
      it "sends notification alert" do
        messages =
          MessageBus.track_publish("/notification-alert/#{user2.id}") do
            described_class.new.execute(
              {
                topic_id: topic.id,
                post_id: post.id,
                assigned_to_id: user2.id,
                assigned_to_type: "User",
                assigned_by_id: user1.id,
                skip_small_action_post: false,
                assignment_id: 1093,
              },
            )
          end

        expect(messages.length).to eq(1)
        expect(messages.first.data[:excerpt]).to eq(
          I18n.t("discourse_assign.topic_assigned_excerpt", title: topic.title),
        )
      end

      it "should publish the right message when private message" do
        user = pm.allowed_users.first
        assign_allowed_group.add(user)

        assert_publish_topic_state(pm, user) do
          described_class.new.execute(
            {
              topic_id: pm.id,
              post_id: pm_post.id,
              assigned_to_id: pm.allowed_users.first.id,
              assigned_to_type: "User",
              assigned_by_id: user1.id,
              skip_small_action_post: false,
              assignment_id: 9023,
            },
          )
        end
      end

      it "sends a high priority notification to the assignee" do
        Notification.expects(:create!).with(
          notification_type: Notification.types[:assigned] || Notification.types[:custom],
          user_id: user2.id,
          topic_id: topic.id,
          post_number: 1,
          high_priority: true,
          data: {
            message: "discourse_assign.assign_notification",
            display_username: user1.username,
            topic_title: topic.title,
            assignment_id: 3194,
          }.to_json,
        )
        described_class.new.execute(
          {
            topic_id: topic.id,
            post_id: post.id,
            assigned_to_id: user2.id,
            assigned_to_type: "User",
            assigned_by_id: user1.id,
            skip_small_action_post: false,
            assignment_id: 3194,
          },
        )
      end
    end

    describe "Group" do
      fab!(:user3) { Fabricate(:user, last_seen_at: 1.day.ago) }
      fab!(:user4) { Fabricate(:user, suspended_till: 1.year.from_now) }
      fab!(:group) { Fabricate(:group, name: "Developers") }
      let(:assignment) do
        Assignment.create!(topic: topic, assigned_by_user: user1, assigned_to: group)
      end

      before do
        group.add(user2)
        group.add(user3)
        group.add(user4)
      end

      it "sends notification alert to all group members" do
        messages =
          MessageBus.track_publish("/notification-alert/#{user2.id}") do
            described_class.new.execute(
              {
                topic_id: topic.id,
                post_id: post.id,
                assigned_to_id: group.id,
                assigned_to_type: "Group",
                assigned_by_id: user1.id,
                skip_small_action_post: false,
                assignment_id: 7839,
              },
            )
          end
        expect(messages.length).to eq(1)
        expect(messages.first.data[:excerpt]).to eq(
          I18n.t(
            "discourse_assign.topic_group_assigned_excerpt",
            title: topic.title,
            group: group.name,
          ),
        )

        messages =
          MessageBus.track_publish("/notification-alert/#{user3.id}") do
            described_class.new.execute(
              {
                topic_id: topic.id,
                post_id: post.id,
                assigned_to_id: group.id,
                assigned_to_type: "Group",
                assigned_by_id: user1.id,
                skip_small_action_post: false,
                assignment_id: 7763,
              },
            )
          end
        expect(messages.length).to eq(1)
        expect(messages.first.data[:excerpt]).to eq(
          I18n.t(
            "discourse_assign.topic_group_assigned_excerpt",
            title: topic.title,
            group: group.name,
          ),
        )

        messages =
          MessageBus.track_publish("/notification-alert/#{user4.id}") do
            described_class.new.execute(
              {
                topic_id: topic.id,
                post_id: post.id,
                assigned_to_id: group.id,
                assigned_to_type: "Group",
                assigned_by_id: user1.id,
                skip_small_action_post: false,
                assignment_id: 8883,
              },
            )
          end
        expect(messages.length).to eq(0)
      end

      it "sends a high priority notification to all group members" do
        [user2, user3, user4].each do |user|
          Notification.expects(:create!).with(
            notification_type: Notification.types[:assigned] || Notification.types[:custom],
            user_id: user.id,
            topic_id: topic.id,
            post_number: 1,
            high_priority: true,
            data: {
              message: "discourse_assign.assign_group_notification",
              display_username: group.name,
              topic_title: topic.title,
              assignment_id: 9429,
            }.to_json,
          )
        end

        described_class.new.execute(
          {
            topic_id: topic.id,
            post_id: post.id,
            assigned_to_id: group.id,
            assigned_to_type: "Group",
            assigned_by_id: user1.id,
            skip_small_action_post: false,
            assignment_id: 9429,
          },
        )
      end
    end
  end
end
