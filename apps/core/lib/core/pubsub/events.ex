defmodule Core.PubSub.VersionCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.VersionUpdated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.DockerNotification, do: use Piazza.PubSub.Event
defmodule Core.PubSub.DockerImageCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.DockerImagesPushed, do: use Piazza.PubSub.Event

defmodule Core.PubSub.InstallationCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.InstallationUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.InstallationDeleted, do: use Piazza.PubSub.Event

defmodule Core.PubSub.SubscriptionUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.SubscriptionCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.PlatformSubscriptionUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.PlatformSubscriptionCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.IncidentCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.IncidentUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.IncidentDeleted, do: use Piazza.PubSub.Event

defmodule Core.PubSub.IncidentMessageCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.IncidentMessageUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.IncidentMessageDeleted, do: use Piazza.PubSub.Event

defmodule Core.PubSub.NotificationCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.ZoomMeetingCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.RepositoryCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.RepositoryUpdated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.GroupCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.GroupDeleted, do: use Piazza.PubSub.Event
defmodule Core.PubSub.GroupUpdated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.GroupMemberCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.GroupMemberDeleted, do: use Piazza.PubSub.Event

defmodule Core.PubSub.RoleCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.RoleUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.RoleDeleted, do: use Piazza.PubSub.Event

defmodule Core.PubSub.IntegrationWebhookCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.IntegrationWebhookUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.IntegrationWebhookDeleted, do: use Piazza.PubSub.Event

defmodule Core.PubSub.UpgradeCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.UpgradeQueueUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.UpgradeQueueCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.ResetTokenCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.RolloutCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.RolloutUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.RolloutPolled, do: use Piazza.PubSub.Event

defmodule Core.PubSub.AccessTokenUsage, do: use Piazza.PubSub.Event
defmodule Core.PubSub.PasswordlessLoginCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.UserUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.UserCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.UserDeleted, do: use Piazza.PubSub.Event
defmodule Core.PubSub.EmailConfirmed, do: use Piazza.PubSub.Event

defmodule Core.PubSub.OIDCProviderUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.OIDCProviderCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.DockerRepositoryUpdated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.LicensePing, do: use Piazza.PubSub.Event

defmodule Core.PubSub.InstallationLocked, do: use Piazza.PubSub.Event
defmodule Core.PubSub.InstallationUnlocked, do: use Piazza.PubSub.Event

defmodule Core.PubSub.TestCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.TestUpdated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.StepLogs, do: use Piazza.PubSub.Event

defmodule Core.PubSub.CacheUser, do: use Piazza.PubSub.Event

defmodule Core.PubSub.InviteCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.PersistedTokenCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.DemoProjectCreated, do: use Piazza.PubSub.Event
defmodule Core.PubSub.DemoProjectDeleted, do: use Piazza.PubSub.Event

defmodule Core.PubSub.ClusterDependencyCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.DeferredUpdateCreated, do: use Piazza.PubSub.Event

defmodule Core.PubSub.UpgradesPromoted, do: use Piazza.PubSub.Event
