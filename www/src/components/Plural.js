import { useContext, useEffect, useState } from 'react'
import {
  Navigate,
  Outlet,
  Route,
  Routes,
} from 'react-router-dom'
import { StripeProvider } from 'react-stripe-elements'
import { Toast } from 'pluralsh-design-system'

import { growthbook } from '../helpers/growthbook'

import ApplicationLayout from './layout/ApplicationLayout'
import BreadcrumbProvider from './Breadcrumbs'
import Chart from './repos/Chart'
import Marketplace from './marketplace/Marketplace'
import Repository from './repository/Repository'
import RepositoryArtifacts from './repository/RepositoryArtifacts'
import RepositoryDeployments from './repository/RepositoryDeployments'
import RepositoryDescription from './repository/RepositoryDescription'
import RepositoryEdit from './repository/RepositoryEdit.tsx'
import RepositoryPackages from './repository/RepositoryPackages'
import RepositoryPackagesDocker from './repository/RepositoryPackagesDocker'
import RepositoryPackagesHelm from './repository/RepositoryPackagesHelm'
import RepositoryPackagesTerraform from './repository/RepositoryPackagesTerraform'
import RepositoryTests from './repository/RepositoryTests'
import Terraform from './repos/Terraform'
import { AccessTokens } from './profile/AccessTokens'
import { Account } from './account/Account'
import { AccountAttributes } from './account/AccountAttributes'
import { Clusters } from './clusters/Clusters.tsx'
import { CurrentUserContext, PluralConfigurationContext, PluralProvider } from './login/CurrentUser'
import { DeviceLoginNotif } from './users/DeviceLoginNotif'
import { Docker, DockerRepository } from './repos/Docker'
import { Domains } from './account/Domains'
import { EabCredentials } from './profile/EabCredentials'
import { EditAccount } from './users/EditAccount'
import { Groups } from './account/Groups'
import { IntegrationPage } from './repos/Integrations'
import { Profile } from './profile/Profile'
import { MyProfile } from './profile/MyProfile'
import { OIDCProvider } from './repository/OIDCProvider'
import { OauthCreator } from './integrations/OauthCreator'
import { PublicKeys } from './profile/PublicKeys'
import { Roles } from './account/Roles'
import { Security } from './profile/Security'
import { ServiceAccounts } from './account/ServiceAccounts'
import { UpgradeQueue } from './clusters/UpgradeQueue'
import { UpgradeQueues } from './clusters/UpgradeQueues'
import { Users } from './account/Users'
import { VerifyEmailConfirmed } from './users/EmailConfirmation'
import { AuditDirectory } from './audits/AuditDirectory'
import { Audits } from './audits/Audits'
import { LoginAudits } from './audits/LoginAudits'
import { AuditChloropleth } from './audits/AuditChloropleth'
import PackageReadme from './repos/common/PackageReadme'
import PackageConfiguration from './repos/common/PackageConfiguration'
import PackageSecurity from './repos/common/PackageSecurity'
import PackageUpdateQueue from './repos/common/PackageUpdateQueue'
import PackageDependencies from './repos/common/PackageDependencies'
import ImagePullMetrics from './repos/common/ImagePullMetrics'
import ImageVulnerabilities from './repos/common/ImageVulnerabilities'
import Publisher from './publisher/Publisher'
import StackApps from './stack/StackApps'
import Stack from './stack/Stack'

import {
  SECTION_APPLICATIONS,
  SECTION_BUILD,
  SECTION_CLI_COMPLETION,
  SECTION_CLI_INSTALLATION,
  SECTION_CREDENTIALS,
  SECTION_GIT,
  SECTION_LAUNCH,
  SECTION_REPOSITORY,
  SECTION_SELECT,
  SECTION_SYNOPSIS,
  SECTION_TO_URL,
  SECTION_WORKSPACE,
} from './shell/constants'

import TerminalIndex from './shell/terminal/TerminalIndex'
import OnboardingRoot from './shell/onboarding/OnboardingRoot'
import OnboardingOAuthCallback from './shell/onboarding/OnboardingOAuthCallback'

import OnboardingApplications from './shell/onboarding/steps/OnboardingApplications'
import OnboardingGit from './shell/onboarding/steps/OnboardingGit'
import OnboardingRepository from './shell/onboarding/steps/OnboardingRepository'
import OnboardingSelect from './shell/onboarding/steps/OnboardingSelect'
import OnboardingBuild from './shell/onboarding/steps/OnboardingBuild'
import OnboardingCredentials from './shell/onboarding/steps/OnboardingCredentials'
import OnboardingWorkspace from './shell/onboarding/steps/OnboardingWorkspace'
import OnboardingSynopsis from './shell/onboarding/steps/OnboardingSynopsis'
import OnboardingLaunch from './shell/onboarding/steps/OnboardingLaunch'
import OnboardingCliInstallation from './shell/onboarding/steps/OnboardingCliInstallation'
import OnboardingCliComplete from './shell/onboarding/steps/OnboardingCliComplete'

function EditBilling(props) {
  return (
    <EditAccount
      {...props}
      billing
    />
  )
}

function WrapStripe({ children }) {
  const { stripePublishableKey } = useContext(PluralConfigurationContext)

  if (!stripePublishableKey) return children

  return (
    <StripeProvider apiKey={stripePublishableKey}>
      {children}
    </StripeProvider>
  )
}

function FallbackRoute() {
  const me = useContext(CurrentUserContext)

  return (
    <Navigate
      replace
      to={me.hasInstallations ? '/installed' : '/marketplace'}
    />
  )
}

function TestBanner() {
  const [enable, setEnable] = useState(true)

  useEffect(() => {
    const timeout = setTimeout(() => setEnable(false), 5000)

    return () => clearTimeout(timeout)
  }, [])

  if (growthbook.isOn('growthbook-test') && enable) {
    return (
      <Toast
        severity="success"
        marginBottom="medium"
        marginRight="xxxxlarge"
      >Growthbook Test!
      </Toast>
    )
  }

  return null
}

export function PluralInner() {
  return (
    <WrapStripe>
      <BreadcrumbProvider>
        <ApplicationLayout>
          <VerifyEmailConfirmed />
          <DeviceLoginNotif />
          <TestBanner />
          <Routes>
            {/* --- OAUTH --- */}
            <Route
              path="/oauth/accept/:service"
              element={<OauthCreator />}
            />
            {/* --- APPLICATIONS --- */}
            <Route
              path="/marketplace"
              element={<Marketplace />}
            />
            <Route
              path="/installed"
              element={<Marketplace installed />}
            />
            {/* --- REPOSITORIES --- */}
            <Route
              path="/repositories/:id/integrations"
              element={<IntegrationPage />}
            />
            {/* --- PROFILE --- */}
            <Route
              path="/profile"
              element={<MyProfile />}
            >
              <Route
                index
                element={(
                  <Navigate
                    replace
                    to="me"
                  />
                )}
              />
              <Route
                path="me"
                element={<Profile />}
              />
              <Route
                path="security"
                element={<Security />}
              />
              <Route
                path="tokens"
                element={<AccessTokens />}
              />
              <Route
                path="keys"
                element={<PublicKeys />}
              />
              <Route
                path="eab"
                element={<EabCredentials />}
              />
            </Route>
            {/* --- REPOSITORY --- */}
            <Route
              path="/repository/:id"
              element={<Repository />}
            >
              <Route
                index
                element={<RepositoryDescription />}
              />
              <Route
                path="packages"
                element={<RepositoryPackages />}
              >
                <Route
                  index
                  element={(
                    <Navigate
                      replace
                      to="helm"
                    />
                  )}
                />
                <Route
                  path="helm"
                  element={<RepositoryPackagesHelm />}
                />
                <Route
                  path="terraform"
                  element={<RepositoryPackagesTerraform />}
                />
                <Route
                  path="docker"
                  element={<RepositoryPackagesDocker />}
                />
              </Route>
              <Route
                path="oidc"
                element={<OIDCProvider />}
              />
              <Route
                path="tests"
                element={<RepositoryTests />}
              />
              <Route
                path="deployments"
                element={<RepositoryDeployments />}
              />
              <Route
                path="artifacts"
                element={<RepositoryArtifacts />}
              />
              <Route
                path="edit"
                element={<RepositoryEdit />}
              />
            </Route>
            {/* --- STACK --- */}
            <Route
              path="/stack/:name"
              element={<Stack />}
            >
              <Route
                index
                element={<StackApps />}
              />
            </Route>
            {/* --- HELM CHARTS --- */}
            <Route
              path="/charts/:chartId"
              element={<Chart />}
            >
              <Route
                index
                element={<PackageReadme />}
              />
              <Route
                path="configuration"
                element={<PackageConfiguration />}
              />
              <Route
                path="dependencies"
                element={<PackageDependencies />}
              />
              <Route
                path="security"
                element={<PackageSecurity />}
              />
              <Route
                path="updatequeue"
                element={<PackageUpdateQueue />}
              />
            </Route>
            {/* --- TERRAFORM CHARTS --- */}
            <Route
              path="/terraform/:tfId"
              element={<Terraform />}
            >
              <Route
                index
                element={<PackageReadme />}
              />
              <Route
                path="configuration"
                element={<PackageConfiguration />}
              />
              <Route
                path="dependencies"
                element={<PackageDependencies />}
              />
              <Route
                path="security"
                element={<PackageSecurity />}
              />
              <Route
                path="updatequeue"
                element={<PackageUpdateQueue />}
              />
            </Route>
            {/* --- DOCKER --- */}
            <Route
              path="/dkr/repo/:id"
              element={<DockerRepository />}
            />
            <Route
              path="/dkr/img/:id"
              element={<Docker />}
            >
              <Route
                index
                element={<ImagePullMetrics />}
              />
              <Route
                path="vulnerabilities"
                element={<ImageVulnerabilities />}
              />
            </Route>
            {/* --- SHELL --- */}
            <Route
              path="shell"
              element={<Outlet />}
            >
              <Route
                index
                element={<TerminalIndex />}
              />
              <Route
                path="onboarding"
                element={<OnboardingRoot />}
              >
                <Route
                  index
                  element={<Navigate to={`/shell/onboarding/${SECTION_TO_URL[SECTION_APPLICATIONS]}`} />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_APPLICATIONS]}
                  element={<OnboardingApplications />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_GIT]}
                  element={<OnboardingGit />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_REPOSITORY]}
                  element={<OnboardingRepository />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_SELECT]}
                  element={<OnboardingSelect />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_BUILD]}
                  element={<OnboardingBuild />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_CREDENTIALS]}
                  element={<OnboardingCredentials />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_WORKSPACE]}
                  element={<OnboardingWorkspace />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_SYNOPSIS]}
                  element={<OnboardingSynopsis />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_LAUNCH]}
                  element={<OnboardingLaunch />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_CLI_INSTALLATION]}
                  element={<OnboardingCliInstallation />}
                />
                <Route
                  path={SECTION_TO_URL[SECTION_CLI_COMPLETION]}
                  element={<OnboardingCliComplete />}
                />
              </Route>
            </Route>
            <Route
              path="/oauth/callback/:provider/shell"
              element={<OnboardingOAuthCallback />}
            />
            {/* --- ACCOUNT --- */}
            <Route
              path="/account/edit/:section/*"
              element={<EditAccount />}
            />
            <Route
              exact
              path="/account"
              element={<Account />}
            >
              <Route
                index
                element={(
                  <Navigate
                    replace
                    to="edit"
                  />
                )}
              />
              <Route
                path="edit"
                element={<AccountAttributes />}
              />
              <Route
                path="users"
                element={<Users />}
              />
              <Route
                path="groups"
                element={<Groups />}
              />
              <Route
                path="service-accounts"
                element={<ServiceAccounts />}
              />
              <Route
                path="roles"
                element={<Roles />}
              />
              <Route
                path="domains"
                element={<Domains />}
              />
            </Route>
            <Route
              path="/account/billing/:section"
              element={<EditBilling />}
            />
            <Route
              path="/audits"
              element={<AuditDirectory />}
            >
              <Route
                index
                element={(
                  <Navigate
                    replace
                    to="logs"
                  />
                )}
              />
              <Route
                path="logs"
                element={<Audits />}
              />
              <Route
                path="logins"
                element={<LoginAudits />}
              />
              <Route
                path="geo"
                element={<AuditChloropleth />}
              />
            </Route>
            {/* --- PUBLISHER --- */}
            <Route
              path="/publisher/:id"
              element={<Publisher />}
            />
            {/* --- UPGRADES --- */}
            <Route
              path="/upgrades/:id"
              element={<UpgradeQueue />}
            />
            <Route
              path="/upgrades"
              element={<UpgradeQueues />}
            />
            <Route
              path="/clusters"
              element={<Clusters />}
            />
            {/* --- 404 --- */}
            <Route
              path="/*"
              element={(
                <FallbackRoute />
              )}
            />
          </Routes>
        </ApplicationLayout>
      </BreadcrumbProvider>
    </WrapStripe>
  )
}

export default function Plural() {
  return (
    <PluralProvider>
      <PluralInner />
    </PluralProvider>
  )
}
