"""
Provides the QSP Audit node implementation.
"""
from queue import Queue
from datetime import datetime
from tempfile import mkstemp
from time import sleep
import os
import json
import logging

from utils.io import fetch_file, digest
from utils.args import replace_args

from hashlib import sha256

class QSPAuditNode:

    def __init__(self, config):
        """
        Builds a QSPAuditNode object from the given input parameters.
        """
        self.__config = config
        self.__filter = self.__config.internal_contract.on("LogAuditRequested")
        self.__exec = False

    def run(self):
        """
        Runs the QSP Audit node in a busy waiting fashion.
        """
        self.__exec = True
        while self.__exec:
            requests = self.__filter.get()

            if requests == []:
                sleep(self.__config.evt_polling)
                continue

            logging.debug("Found incomming audit requests: {0}".format(
                str(requests)
            ))

            # Process all incoming requests
            for audit_request in requests:
                price = audit_request['args']['price']
                request_id = audit_request['args']['requestId']

                # Accepts all requests whose reward is at least as
                # high as given by min_reward
                if price >= self.__config.min_price:
                    logging.debug("{0} Accepted processing audit request: {1}".format(
                        str(request_id), str(audit_request)
                    ))
                    try:
                        requestor = audit_request['args']['requestor']
                        contract_uri = audit_request['args']['uri']

                        report = self.audit(requestor, contract_uri, request_id)

                        if report is None:
                          logging.exception(
                              "{0} Could not generate report".format(str(request_id)))
                          pass
                        
                        report_json = json.dumps(report)
                        logging.debug(
                            "{0} Generated report is {1}. Submitting".format(str(request_id), str(report_json)))
                        tx = self.__submitReport(
                            request_id, requestor, contract_uri, report_json)
                        logging.debug(
                            "{0} Report is sucessfully submitted: Hash is {1}".format(str(request_id), str(tx)))

                    except Exception:
                        logging.exception(
                            "{0} Unexpected error when performing audit".format(str(request_id)))
                        pass

                else:
                    logging.debug(
                        "{0} Declining processing audit request: {1}. Not enough incentive".format(
                            str(request_id), str(audit_request)
                        )
                    )

    def stop(self):
        """
        Signals to the executing QSP audit node that is should stop the execution of the node.
        """
        self.__exec = False

    def audit(self, requestor, uri, request_id):
        """
        Audits a target contract.
        """
        logging.info("{0} Executing audit on contract at {1}".format(request_id, uri))

        target_contract = fetch_file(uri)

        report = self.__config.analyzer.check(
            target_contract,
            self.__config.analyzer_output,
        )
        
        report_as_string = str(json.dumps(report));
        
        upload_result = self.__config.report_uploader.upload(report_as_string);
        logging.info(
            "{0} Report upload result: {1}".format(request_id, upload_result))
        
        if (upload_result['success'] is False):
          logging.exception(
              "{0} Unexpected error when uploading report: {1}".format(request_id, json.dumps(upload_result)))
          return None

        return {
            'auditor': self.__config.account,
            'requestor': str(requestor),
            'contract_uri': str(uri),
            'contract_sha256': str(digest(target_contract)),
            'report_uri': upload_result['url'],
            'report_sha256': sha256(report_as_string.encode()).hexdigest(),
            'timestamp': str(datetime.utcnow()),
        }

    def __submitReport(self, request_id, requestor, contract_uri, report):
        """
        Submits the audit report to the entire QSP network.
        """
        gas = self.__config.default_gas

        if gas is None:
            args = {'from': self.__config.account}
        else:
            args = {'from': self.__config.account, 'gas': int(gas)}

        self.__config.wallet_session_manager.unlock(self.__config.account_ttl)
        return self.__config.internal_contract.transact(args).submitReport(
            request_id,
            requestor,
            contract_uri,
            report,
        )
