# Deprecated alias so Solid Queue jobs already serialized under this class name
# still deserialize after the rename to FinalApprovalNotificationJob.
class DeanApprovalNotificationJob < FinalApprovalNotificationJob
end
